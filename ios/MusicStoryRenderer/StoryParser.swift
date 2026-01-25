import Foundation

struct ParsedStory {
    let document: StoryDocument?
    let diagnostics: [ValidationDiagnostic]
}

struct StoryParser {
    func parse(package: StoryPackage) -> ParsedStory {
        parse(storyText: package.storyText, assetBaseURL: package.assetBaseURL)
    }

    func parse(storyText: String, assetBaseURL: URL?) -> ParsedStory {
        var diagnostics: [ValidationDiagnostic] = []
        guard let split = splitFrontMatter(from: storyText, diagnostics: &diagnostics) else {
            return ParsedStory(document: nil, diagnostics: diagnostics)
        }

        let resolver = StoryAssetResolver(baseURL: assetBaseURL)
        var frontMatterParser = FrontMatterParser(text: split.frontMatter)
        let values = frontMatterParser.parse()
        diagnostics.append(contentsOf: frontMatterParser.diagnostics)

        guard let frontMatter = mapFrontMatter(values, resolver: resolver, diagnostics: &diagnostics) else {
            return ParsedStory(document: nil, diagnostics: diagnostics)
        }

        var bodyDiagnostics: [ValidationDiagnostic] = []
        let sections = parseBody(
            split.body,
            sectionMetadata: frontMatter.sections,
            resolver: resolver,
            diagnostics: &bodyDiagnostics,
        )
        diagnostics.append(contentsOf: bodyDiagnostics)

        let hasErrors = diagnostics.contains { $0.severity == .error }
        let document = StoryDocument(
            schemaVersion: frontMatter.schemaVersion,
            id: frontMatter.id,
            title: frontMatter.title,
            subtitle: frontMatter.subtitle,
            deck: frontMatter.deck,
            authors: frontMatter.authors,
            editors: frontMatter.editors,
            publishDate: frontMatter.publishDate,
            tags: frontMatter.tags,
            locale: frontMatter.locale,
            accentColor: frontMatter.accentColor,
            heroGradient: frontMatter.heroGradient,
            typeRamp: frontMatter.typeRamp,
            heroImage: frontMatter.heroImage,
            leadArt: frontMatter.leadArt,
            sections: sections,
            media: frontMatter.media,
        )

        return ParsedStory(document: hasErrors ? nil : document, diagnostics: diagnostics)
    }

    private func splitFrontMatter(
        from storyText: String,
        diagnostics: inout [ValidationDiagnostic],
    ) -> (frontMatter: String, body: String)? {
        let lines = storyText.components(separatedBy: .newlines)
        guard let firstLine = lines.first,
              firstLine.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
        else {
            diagnostics.append(.error(code: "missing_front_matter", message: "Missing front matter header '---'."))
            return nil
        }

        var closingIndex: Int?
        for index in 1 ..< lines.count where lines[index].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
            closingIndex = index
            break
        }

        guard let endIndex = closingIndex else {
            diagnostics.append(.error(code: "missing_front_matter_end", message: "Missing closing front matter '---'."))
            return nil
        }

        let frontMatterLines = lines[1 ..< endIndex]
        let bodyLines = lines.suffix(from: endIndex + 1)
        return (frontMatterLines.joined(separator: "\n"), bodyLines.joined(separator: "\n"))
    }

    private func mapFrontMatter(
        _ values: [String: Any],
        resolver: StoryAssetResolver,
        diagnostics: inout [ValidationDiagnostic],
    ) -> FrontMatterData? {
        guard let schemaVersion = stringValue(
            "schema_version",
            from: values,
            required: true,
            diagnostics: &diagnostics,
        ),
            let storyId = stringValue("id", from: values, required: true, diagnostics: &diagnostics),
            let title = stringValue("title", from: values, required: true, diagnostics: &diagnostics)
        else {
            return nil
        }

        let subtitle = stringValue("subtitle", from: values, required: false, diagnostics: &diagnostics)
        let deck = stringValue("deck", from: values, required: false, diagnostics: &diagnostics)
        let authors = stringList("authors", from: values, required: true, diagnostics: &diagnostics)
        let editors = stringList("editors", from: values, required: false, diagnostics: &diagnostics)
        let publishDateValue = stringValue("publish_date", from: values, required: true, diagnostics: &diagnostics)
        let tags = stringList("tags", from: values, required: false, diagnostics: &diagnostics)
        let locale = stringValue("locale", from: values, required: false, diagnostics: &diagnostics)
        let accentColor = stringValue("accentColor", from: values, required: false, diagnostics: &diagnostics)
        let heroGradient = stringList("heroGradient", from: values, required: false, diagnostics: &diagnostics)
        let typeRamp = parseTypeRamp(values["typeRamp"], diagnostics: &diagnostics)

        let publishDate = parsePublishDate(publishDateValue, diagnostics: &diagnostics)
        let heroImage = parseHeroImage(values, resolver: resolver, diagnostics: &diagnostics)
        let leadArt = parseLeadArt(values, resolver: resolver, diagnostics: &diagnostics)
        let sectionMetadata = parseSectionMetadata(values, diagnostics: &diagnostics)
        if sectionMetadata.isEmpty {
            diagnostics.append(.error(code: "missing_required_field", message: "At least one section is required."))
        }

        let mediaReferences = parseMediaReferences(values, resolver: resolver, diagnostics: &diagnostics)
        if mediaReferences.isEmpty {
            diagnostics.append(.error(
                code: "missing_required_field",
                message: "At least one media reference is required.",
            ))
        }

        guard let publishDate else {
            return nil
        }

        return FrontMatterData(
            schemaVersion: schemaVersion,
            id: storyId,
            title: title,
            subtitle: subtitle,
            deck: deck,
            authors: authors,
            editors: editors,
            publishDate: publishDate,
            tags: tags,
            locale: locale,
            accentColor: accentColor,
            heroGradient: heroGradient,
            typeRamp: typeRamp,
            heroImage: heroImage,
            leadArt: leadArt,
            sections: sectionMetadata,
            media: mediaReferences,
        )
    }

    private func stringValue(
        _ key: String,
        from values: [String: Any],
        required: Bool,
        diagnostics: inout [ValidationDiagnostic],
    ) -> String? {
        if let value = values[key] as? String, !value.isEmpty {
            return value
        }
        if required {
            diagnostics.append(.error(code: "missing_required_field", message: "Missing required field '\(key)'."))
        }
        return nil
    }

    private func stringList(
        _ key: String,
        from values: [String: Any],
        required: Bool,
        diagnostics: inout [ValidationDiagnostic],
    ) -> [String] {
        if let list = values[key] as? [String] {
            return list.filter { !$0.isEmpty }
        }
        if let value = values[key] as? String, !value.isEmpty {
            return [value]
        }
        if required {
            diagnostics.append(.error(code: "missing_required_field", message: "Missing required field '\(key)'."))
        }
        return []
    }

    private func parseHeroImage(
        _ values: [String: Any],
        resolver: StoryAssetResolver,
        diagnostics: inout [ValidationDiagnostic],
    ) -> StoryHeroImage? {
        guard let heroData = values["hero_image"] as? [String: String] else {
            return nil
        }
        guard let src = heroData["src"], let alt = heroData["alt"] else {
            diagnostics.append(.error(code: "missing_required_field", message: "Hero image requires src and alt."))
            return nil
        }
        let resolvedSource = resolver.resolveString(from: src)
        return StoryHeroImage(source: resolvedSource, altText: alt, credit: heroData["credit"])
    }

    private func parseLeadArt(
        _ values: [String: Any],
        resolver: StoryAssetResolver,
        diagnostics: inout [ValidationDiagnostic],
    ) -> StoryLeadArt? {
        guard let artData = values["leadArt"] as? [String: String] else {
            return nil
        }
        guard let src = artData["src"], let alt = artData["alt"] else {
            diagnostics.append(.warning(code: "invalid_lead_art", message: "leadArt requires src and alt."))
            return nil
        }
        let resolvedSource = resolver.resolveString(from: src)
        return StoryLeadArt(
            source: resolvedSource,
            altText: alt,
            caption: artData["caption"],
            credit: artData["credit"],
        )
    }

    private func parseTypeRamp(_ value: Any?, diagnostics: inout [ValidationDiagnostic]) -> StoryTypeRamp? {
        guard let rawValue = value as? String, rawValue.isEmpty == false else {
            return nil
        }
        if let ramp = StoryTypeRamp(rawValue: rawValue.lowercased()) {
            return ramp
        }
        diagnostics.append(.warning(
            code: "invalid_type_ramp",
            message: "typeRamp must be serif, sans, or slab.",
        ))
        return nil
    }

    private func parseSectionMetadata(
        _ values: [String: Any],
        diagnostics: inout [ValidationDiagnostic],
    ) -> [SectionMetadata] {
        let sectionEntries = values["sections"] as? [[String: String]] ?? []
        var sectionMetadata: [SectionMetadata] = []
        for section in sectionEntries {
            guard let id = section["id"], let sectionTitle = section["title"] else {
                diagnostics.append(.error(
                    code: "missing_required_field",
                    message: "Section entries require id and title.",
                ))
                continue
            }
            sectionMetadata.append(
                SectionMetadata(
                    id: id,
                    title: sectionTitle,
                    layout: section["layout"],
                    leadMediaKey: section["lead_media"],
                ),
            )
        }
        return sectionMetadata
    }

    private func parseMediaReferences(
        _ values: [String: Any],
        resolver: StoryAssetResolver,
        diagnostics: inout [ValidationDiagnostic],
    ) -> [StoryMediaReference] {
        let mediaEntries = values["media"] as? [[String: String]] ?? []
        var mediaReferences: [StoryMediaReference] = []
        var seenKeys = Set<String>()
        for entry in mediaEntries {
            guard let key = entry["key"],
                  let typeValue = entry["type"],
                  let mediaType = StoryMediaType(storageValue: typeValue),
                  let appleMusicId = entry["apple_music_id"],
                  let mediaTitle = entry["title"],
                  let artist = entry["artist"]
            else {
                diagnostics.append(.error(
                    code: "missing_required_field",
                    message: "Media entries require key, type, apple_music_id, title, and artist.",
                ))
                continue
            }

            if seenKeys.contains(key) {
                diagnostics.append(.error(code: "duplicate_media_key", message: "Duplicate media key '\(key)'."))
                continue
            }
            seenKeys.insert(key)

            let artworkURL = resolver.resolveURL(from: entry["artwork_url"])
            let duration = entry["duration_ms"].flatMap { Int($0) }
            mediaReferences.append(
                StoryMediaReference(
                    key: key,
                    type: mediaType,
                    appleMusicId: appleMusicId,
                    title: mediaTitle,
                    artist: artist,
                    artworkURL: artworkURL,
                    durationMilliseconds: duration,
                ),
            )
        }
        return mediaReferences
    }

    private func parsePublishDate(_ value: String?, diagnostics: inout [ValidationDiagnostic]) -> Date? {
        guard let value else {
            return nil
        }
        if let date = DateFormatters.publishDate.date(from: value) {
            return date
        }
        diagnostics.append(.error(code: "invalid_publish_date", message: "publish_date must use YYYY-MM-DD."))
        return nil
    }

    private func parseBody(
        _ bodyText: String,
        sectionMetadata: [SectionMetadata],
        resolver: StoryAssetResolver,
        diagnostics: inout [ValidationDiagnostic],
    ) -> [StorySection] {
        let matches = Regex.section.matches(in: bodyText, range: NSRange(bodyText.startIndex..., in: bodyText))
        if matches.isEmpty {
            diagnostics.append(.error(code: "missing_sections", message: "No <Section> blocks found in story body."))
        }

        var sections: [StorySection] = []
        var lastIndex = bodyText.startIndex
        let metadataById = Dictionary(uniqueKeysWithValues: sectionMetadata.map { ($0.id, $0) })
        var seenSectionIds = Set<String>()

        for match in matches {
            guard let matchRange = Range(match.range, in: bodyText),
                  let attributeRange = Range(match.range(at: 1), in: bodyText),
                  let contentRange = Range(match.range(at: 2), in: bodyText)
            else {
                continue
            }

            let leadingText = bodyText[lastIndex ..< matchRange.lowerBound]
            if leadingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                diagnostics.append(.error(
                    code: "text_outside_section",
                    message: "Text found outside of <Section> blocks.",
                ))
            }
            lastIndex = matchRange.upperBound

            let attributeText = String(bodyText[attributeRange])
            let contentText = String(bodyText[contentRange])
            let attributes = parseAttributes(from: attributeText)

            guard let sectionId = attributes["id"] else {
                diagnostics.append(.error(
                    code: "missing_section_id",
                    message: "<Section> is missing required id attribute.",
                ))
                continue
            }

            if seenSectionIds.contains(sectionId) {
                diagnostics.append(.error(
                    code: "duplicate_section_id",
                    message: "Duplicate section id '\(sectionId)'.",
                ))
            }
            seenSectionIds.insert(sectionId)

            if contentText.contains("<Section") {
                diagnostics.append(.error(
                    code: "nested_section",
                    message: "Nested <Section> blocks are not supported.",
                    location: sectionId,
                ))
            }

            let metadata = metadataById[sectionId]
            if metadata == nil {
                diagnostics.append(.error(
                    code: "section_missing_metadata",
                    message: "Section '\(sectionId)' is missing from front matter.",
                ))
            }

            let title = attributes["title"] ?? metadata?.title
            if title == nil {
                diagnostics.append(.error(
                    code: "missing_section_title",
                    message: "Section '\(sectionId)' is missing a title.",
                ))
            } else if let metadataTitle = metadata?.title, title != metadataTitle {
                diagnostics.append(.warning(
                    code: "section_title_mismatch",
                    message: "Section '\(sectionId)' title does not match front matter.",
                ))
            }

            let layout = normalizedLayout(
                attributes["layout"] ?? metadata?.layout,
                sectionId: sectionId,
                diagnostics: &diagnostics,
            )
            let leadMediaKey = metadata?.leadMediaKey
            let blocks = parseSectionBlocks(
                contentText,
                sectionId: sectionId,
                resolver: resolver,
                diagnostics: &diagnostics,
            )

            sections.append(
                StorySection(
                    id: sectionId,
                    title: title,
                    layout: layout,
                    leadMediaKey: leadMediaKey,
                    blocks: blocks,
                ),
            )
        }

        let trailingText = bodyText[lastIndex...]
        if trailingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            diagnostics.append(.error(code: "text_outside_section", message: "Text found outside of <Section> blocks."))
        }

        let unusedMetadata = Set(metadataById.keys).subtracting(seenSectionIds)
        if unusedMetadata.isEmpty == false {
            diagnostics.append(.warning(
                code: "unused_section_metadata",
                message: "Front matter includes sections not present in MDX body.",
            ))
        }

        return sections
    }

    private enum BlockKind {
        case media
        case dropQuote
        case sideNote
        case featureBox
        case factGrid
        case timeline
        case gallery
        case fullBleed
    }

    private struct BlockPattern {
        let kind: BlockKind
        let regex: NSRegularExpression
        let attributeIndex: Int?
        let contentIndex: Int?

        static let allCases: [BlockPattern] = [
            BlockPattern(kind: .media, regex: Regex.mediaRef, attributeIndex: 1, contentIndex: nil),
            BlockPattern(kind: .dropQuote, regex: Regex.dropQuote, attributeIndex: 1, contentIndex: 2),
            BlockPattern(kind: .sideNote, regex: Regex.sideNote, attributeIndex: 1, contentIndex: 2),
            BlockPattern(kind: .featureBox, regex: Regex.featureBox, attributeIndex: 1, contentIndex: 2),
            BlockPattern(kind: .factGrid, regex: Regex.factGrid, attributeIndex: nil, contentIndex: 1),
            BlockPattern(kind: .timeline, regex: Regex.timeline, attributeIndex: nil, contentIndex: 1),
            BlockPattern(kind: .gallery, regex: Regex.gallery, attributeIndex: nil, contentIndex: 1),
            BlockPattern(kind: .fullBleed, regex: Regex.fullBleed, attributeIndex: 1, contentIndex: nil),
        ]

        func attributeRange(in text: String, match: NSTextCheckingResult) -> String? {
            guard let attributeIndex else {
                return nil
            }
            guard let range = Range(match.range(at: attributeIndex), in: text) else {
                return nil
            }
            return String(text[range])
        }

        func contentRange(in text: String, match: NSTextCheckingResult) -> String? {
            guard let contentIndex else {
                return nil
            }
            guard let range = Range(match.range(at: contentIndex), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }

    private func parseSectionBlocks(
        _ contentText: String,
        sectionId: String,
        resolver: StoryAssetResolver,
        diagnostics: inout [ValidationDiagnostic],
    ) -> [StoryBlock] {
        var blocks: [StoryBlock] = []
        var paragraphIndex = 0
        var mediaIndex = 0
        var dropQuoteIndex = 0
        var sideNoteIndex = 0
        var featureBoxIndex = 0
        var factGridIndex = 0
        var timelineIndex = 0
        var galleryIndex = 0
        var fullBleedIndex = 0
        var lastIndex = contentText.startIndex

        func appendParagraphs(from text: String) {
            let paragraphs = splitParagraphs(text)
            for paragraph in paragraphs {
                let identifier = "\(sectionId)-paragraph-\(paragraphIndex)"
                paragraphIndex += 1
                blocks.append(.paragraph(id: identifier, text: paragraph))
            }
        }

        func nextMatch(from index: String.Index) -> (BlockPattern, NSTextCheckingResult)? {
            let searchRange = NSRange(index..<contentText.endIndex, in: contentText)
            var candidates: [(BlockPattern, NSTextCheckingResult)] = []
            for pattern in BlockPattern.allCases {
                if let match = pattern.regex.firstMatch(in: contentText, range: searchRange) {
                    candidates.append((pattern, match))
                }
            }
            return candidates.min { lhs, rhs in
                lhs.1.range.location < rhs.1.range.location
            }
        }

        while let (pattern, match) = nextMatch(from: lastIndex) {
            guard let matchRange = Range(match.range, in: contentText) else {
                break
            }
            let leadingText = String(contentText[lastIndex ..< matchRange.lowerBound])
            appendParagraphs(from: leadingText)
            lastIndex = matchRange.upperBound

            let attributeText = pattern.attributeRange(in: contentText, match: match) ?? ""
            let attributes = parseAttributes(from: attributeText)
            let bodyText = pattern.contentRange(in: contentText, match: match) ?? ""

            switch pattern.kind {
            case .media:
                guard let referenceKey = attributes["ref"] else {
                    diagnostics.append(.error(
                        code: "missing_media_ref",
                        message: "<MediaRef> is missing required ref attribute.",
                        location: sectionId,
                    ))
                    continue
                }
                let intent = parseIntent(attributes["intent"], diagnostics: &diagnostics, referenceKey: referenceKey)
                let identifier = "\(sectionId)-media-\(mediaIndex)"
                mediaIndex += 1
                blocks.append(.media(id: identifier, referenceKey: referenceKey, intent: intent))
            case .dropQuote:
                let identifier = "\(sectionId)-dropquote-\(dropQuoteIndex)"
                dropQuoteIndex += 1
                let text = bodyText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                blocks.append(.dropQuote(id: identifier, text: text, attribution: attributes["attribution"]))
            case .sideNote:
                let identifier = "\(sectionId)-sidenote-\(sideNoteIndex)"
                sideNoteIndex += 1
                let text = bodyText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                blocks.append(.sideNote(id: identifier, text: text, label: attributes["label"]))
            case .featureBox:
                let identifier = "\(sectionId)-feature-\(featureBoxIndex)"
                featureBoxIndex += 1
                let body = bodyText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                let expandable = (attributes["expandable"] ?? "false").lowercased() == "true"
                blocks.append(.featureBox(
                    id: identifier,
                    title: attributes["title"],
                    summary: attributes["summary"],
                    expandable: expandable,
                    body: body,
                ))
            case .factGrid:
                let identifier = "\(sectionId)-facts-\(factGridIndex)"
                factGridIndex += 1
                let facts = parseFactGrid(from: bodyText, diagnostics: &diagnostics, sectionId: sectionId)
                blocks.append(.factGrid(id: identifier, facts: facts))
            case .timeline:
                let identifier = "\(sectionId)-timeline-\(timelineIndex)"
                timelineIndex += 1
                let items = parseTimeline(from: bodyText, diagnostics: &diagnostics, sectionId: sectionId)
                blocks.append(.timeline(id: identifier, items: items))
            case .gallery:
                let identifier = "\(sectionId)-gallery-\(galleryIndex)"
                galleryIndex += 1
                let images = parseGallery(
                    from: bodyText,
                    resolver: resolver,
                    diagnostics: &diagnostics,
                    sectionId: sectionId,
                )
                blocks.append(.gallery(id: identifier, images: images))
            case .fullBleed:
                let identifier = "\(sectionId)-fullbleed-\(fullBleedIndex)"
                fullBleedIndex += 1
                if let block = parseFullBleed(
                    attributes: attributes,
                    resolver: resolver,
                    diagnostics: &diagnostics,
                    sectionId: sectionId,
                    identifier: identifier,
                ) {
                    blocks.append(block)
                }
            }
        }

        let trailingText = String(contentText[lastIndex...])
        appendParagraphs(from: trailingText)

        let unsupportedContent = Regex.strippingPatterns.reduce(contentText) { partial, regex in
            regex.stringByReplacingMatches(
                in: partial,
                range: NSRange(partial.startIndex..., in: partial),
                withTemplate: "",
            )
        }
        if unsupportedContent.contains("<") {
            diagnostics.append(.warning(
                code: "unsupported_html",
                message: "Unsupported HTML or components found in section '\(sectionId)'.",
            ))
        }

        return blocks
    }

    private func parseFactGrid(
        from text: String,
        diagnostics: inout [ValidationDiagnostic],
        sectionId: String,
    ) -> [StoryFact] {
        let matches = Regex.fact.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var facts: [StoryFact] = []
        for match in matches {
            guard let attributeRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            let attributes = parseAttributes(from: String(text[attributeRange]))
            guard let label = attributes["label"], let value = attributes["value"] else {
                diagnostics.append(.warning(
                    code: "invalid_fact",
                    message: "Fact entries require label and value in section '\(sectionId)'.",
                ))
                continue
            }
            facts.append(StoryFact(label: label, value: value))
        }
        return facts
    }

    private func parseTimeline(
        from text: String,
        diagnostics: inout [ValidationDiagnostic],
        sectionId: String,
    ) -> [StoryTimelineItem] {
        let matches = Regex.timelineItem.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var items: [StoryTimelineItem] = []
        for match in matches {
            guard let attributeRange = Range(match.range(at: 1), in: text),
                  let contentRange = Range(match.range(at: 2), in: text)
            else {
                continue
            }
            let attributes = parseAttributes(from: String(text[attributeRange]))
            guard let year = attributes["year"] else {
                diagnostics.append(.warning(
                    code: "invalid_timeline_item",
                    message: "Timeline items require year in section '\(sectionId)'.",
                ))
                continue
            }
            let body = String(text[contentRange]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            items.append(StoryTimelineItem(year: year, text: body))
        }
        return items
    }

    private func parseGallery(
        from text: String,
        resolver: StoryAssetResolver,
        diagnostics: inout [ValidationDiagnostic],
        sectionId: String,
    ) -> [StoryGalleryImage] {
        let matches = Regex.galleryImage.matches(in: text, range: NSRange(text.startIndex..., in: text))
        var images: [StoryGalleryImage] = []
        for match in matches {
            guard let attributeRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            let attributes = parseAttributes(from: String(text[attributeRange]))
            guard let src = attributes["src"], let alt = attributes["alt"] else {
                diagnostics.append(.warning(
                    code: "invalid_gallery_image",
                    message: "GalleryImage requires src and alt in section '\(sectionId)'.",
                ))
                continue
            }
            images.append(StoryGalleryImage(
                source: resolver.resolveString(from: src),
                altText: alt,
                caption: attributes["caption"],
                credit: attributes["credit"],
            ))
        }
        return images
    }

    private func parseFullBleed(
        attributes: [String: String],
        resolver: StoryAssetResolver,
        diagnostics: inout [ValidationDiagnostic],
        sectionId: String,
        identifier: String,
    ) -> StoryBlock? {
        guard let src = attributes["src"], let alt = attributes["alt"] else {
            diagnostics.append(.warning(
                code: "invalid_full_bleed",
                message: "FullBleed requires src and alt in section '\(sectionId)'.",
            ))
            return nil
        }
        let kindValue = (attributes["kind"] ?? "image").lowercased()
        let kind = StoryFullBleedKind(rawValue: kindValue) ?? .image
        if StoryFullBleedKind(rawValue: kindValue) == nil && kindValue.isEmpty == false {
            diagnostics.append(.warning(
                code: "invalid_full_bleed_kind",
                message: "FullBleed kind must be image or video in section '\(sectionId)'.",
            ))
        }
        return .fullBleed(
            id: identifier,
            source: resolver.resolveString(from: src),
            altText: alt,
            caption: attributes["caption"],
            credit: attributes["credit"],
            kind: kind,
        )
    }

    private func parseAttributes(from text: String) -> [String: String] {
        var attributes: [String: String] = [:]
        for match in Regex.attributes.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let keyRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text)
            else {
                continue
            }
            attributes[String(text[keyRange])] = String(text[valueRange])
        }
        return attributes
    }

    private func normalizedLayout(
        _ value: String?,
        sectionId: String,
        diagnostics: inout [ValidationDiagnostic],
    ) -> String? {
        let normalized = (value ?? "body").lowercased()
        if normalized == "lede" || normalized == "body" {
            return normalized
        }
        diagnostics.append(.warning(
            code: "invalid_layout",
            message: "Section '\(sectionId)' has unsupported layout '\(normalized)'.",
        ))
        return "body"
    }

    private func parseIntent(
        _ value: String?,
        diagnostics: inout [ValidationDiagnostic],
        referenceKey: String,
    ) -> PlaybackIntent {
        guard let value else {
            return .preview
        }
        switch value.lowercased() {
        case "preview":
            return .preview
        case "full":
            return .full
        case "autoplay":
            return .autoplay
        default:
            diagnostics.append(.warning(
                code: "invalid_intent",
                message: "MediaRef '\(referenceKey)' uses unsupported intent '\(value)'.",
            ))
            return .preview
        }
    }

    private func splitParagraphs(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var paragraphs: [String] = []
        var currentLines: [String] = []

        for line in normalized.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if currentLines.isEmpty == false {
                    paragraphs.append(joinParagraphLines(currentLines))
                    currentLines = []
                }
            } else {
                currentLines.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        if currentLines.isEmpty == false {
            paragraphs.append(joinParagraphLines(currentLines))
        }

        return paragraphs.filter { !$0.isEmpty }
    }

    private func joinParagraphLines(_ lines: [String]) -> String {
        lines.joined(separator: " ")
    }
}

private struct FrontMatterData {
    let schemaVersion: String
    let id: String
    let title: String
    let subtitle: String?
    let deck: String?
    let authors: [String]
    let editors: [String]
    let publishDate: Date
    let tags: [String]
    let locale: String?
    let accentColor: String?
    let heroGradient: [String]
    let typeRamp: StoryTypeRamp?
    let heroImage: StoryHeroImage?
    let leadArt: StoryLeadArt?
    let sections: [SectionMetadata]
    let media: [StoryMediaReference]
}

private struct SectionMetadata {
    let id: String
    let title: String
    let layout: String?
    let leadMediaKey: String?
}

private struct StoryAssetResolver {
    let baseURL: URL?

    func resolveURL(from value: String?) -> URL? {
        guard let value, value.isEmpty == false else {
            return nil
        }
        if let url = URL(string: value), url.scheme != nil {
            return url
        }
        guard let baseURL else {
            return nil
        }
        return baseURL.appendingPathComponent(value)
    }

    func resolveString(from value: String) -> String {
        resolveURL(from: value)?.absoluteString ?? value
    }
}

private struct FrontMatterParser {
    private let lines: [YAMLLine]
    private(set) var diagnostics: [ValidationDiagnostic] = []
    private var index = 0

    init(text: String) {
        lines = text
            .components(separatedBy: .newlines)
            .map { YAMLLine(raw: $0) }
    }

    mutating func parse() -> [String: Any] {
        var values: [String: Any] = [:]
        while index < lines.count {
            let line = lines[index]
            if line.trimmed.isEmpty {
                index += 1
                continue
            }
            guard line.indentation == 0 else {
                diagnostics.append(.warning(
                    code: "invalid_indentation",
                    message: "Unexpected indentation in front matter.",
                ))
                index += 1
                continue
            }
            guard let (key, value) = splitKeyValue(line.trimmed) else {
                diagnostics.append(.warning(
                    code: "invalid_front_matter",
                    message: "Unable to parse front matter line: \(line.raw).",
                ))
                index += 1
                continue
            }

            if value.isEmpty {
                index += 1
                switch key {
                case "hero_image":
                    values[key] = parseObject(indentationLevel: 2)
                case "leadArt":
                    values[key] = parseObject(indentationLevel: 2)
                case "sections", "media":
                    values[key] = parseListOfMaps(indentationLevel: 2)
                case "authors", "editors", "tags", "heroGradient":
                    values[key] = parseStringList(indentationLevel: 2)
                default:
                    values[key] = ""
                }
            } else if value.hasPrefix("[") {
                values[key] = parseInlineArray(value)
                index += 1
            } else {
                values[key] = parseScalar(value)
                index += 1
            }
        }
        return values
    }

    private mutating func parseObject(indentationLevel: Int) -> [String: String] {
        var result: [String: String] = [:]
        while index < lines.count {
            let line = lines[index]
            if line.trimmed.isEmpty {
                index += 1
                continue
            }
            if line.indentation < indentationLevel {
                break
            }
            if line.indentation > indentationLevel {
                diagnostics.append(.warning(
                    code: "invalid_indentation",
                    message: "Unexpected indentation in front matter object.",
                ))
                index += 1
                continue
            }
            guard let (key, value) = splitKeyValue(line.trimmed) else {
                diagnostics.append(.warning(
                    code: "invalid_front_matter",
                    message: "Unable to parse front matter line: \(line.raw).",
                ))
                index += 1
                continue
            }
            result[key] = parseScalar(value)
            index += 1
        }
        return result
    }

    private mutating func parseListOfMaps(indentationLevel: Int) -> [[String: String]] {
        var items: [[String: String]] = []
        while index < lines.count {
            let line = lines[index]
            if line.trimmed.isEmpty {
                index += 1
                continue
            }
            if line.indentation < indentationLevel {
                break
            }
            guard line.trimmed.hasPrefix("- ") else {
                diagnostics.append(.warning(code: "invalid_list", message: "Expected list entry in front matter."))
                index += 1
                continue
            }
            let itemIndentation = line.indentation
            var item: [String: String] = [:]
            let remainder = line.trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
            if remainder.isEmpty == false, let (key, value) = splitKeyValue(String(remainder)) {
                item[key] = parseScalar(value)
            }
            index += 1
            while index < lines.count {
                let nextLine = lines[index]
                if nextLine.trimmed.isEmpty {
                    index += 1
                    continue
                }
                if nextLine.indentation <= itemIndentation {
                    break
                }
                guard let (key, value) = splitKeyValue(nextLine.trimmed) else {
                    diagnostics.append(.warning(
                        code: "invalid_front_matter",
                        message: "Unable to parse front matter line: \(nextLine.raw).",
                    ))
                    index += 1
                    continue
                }
                item[key] = parseScalar(value)
                index += 1
            }
            items.append(item)
        }
        return items
    }

    private mutating func parseStringList(indentationLevel: Int) -> [String] {
        var items: [String] = []
        while index < lines.count {
            let line = lines[index]
            if line.trimmed.isEmpty {
                index += 1
                continue
            }
            if line.indentation < indentationLevel {
                break
            }
            guard line.trimmed.hasPrefix("- ") else {
                diagnostics.append(.warning(code: "invalid_list", message: "Expected list entry in front matter."))
                index += 1
                continue
            }
            let value = line.trimmed.dropFirst(2)
            items.append(parseScalar(String(value)))
            index += 1
        }
        return items
    }

    private func splitKeyValue(_ line: String) -> (String, String)? {
        guard let separatorIndex = line.firstIndex(of: ":") else {
            return nil
        }
        let key = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
        let value = String(line[line.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespaces)
        return (key, value)
    }

    private func parseScalar(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private func parseInlineArray(_ value: String) -> [String] {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else {
            return []
        }
        let inner = trimmed.dropFirst().dropLast()
        if inner.isEmpty {
            return []
        }
        return inner.split(separator: ",").map { parseScalar(String($0)) }
    }

    private struct YAMLLine {
        let raw: String
        let indentation: Int
        let trimmed: String

        init(raw: String) {
            self.raw = raw
            indentation = raw.prefix(while: { $0 == " " }).count
            trimmed = raw.trimmingCharacters(in: .whitespaces)
        }
    }
}

private enum Regex {
    static let section: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<Section\\s+([^>]+)>(.*?)</Section>",
                options: [.dotMatchesLineSeparators],
            )
        } catch {
            preconditionFailure("Invalid section regex: \(error)")
        }
    }()

    static let mediaRef: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<MediaRef\\s+([^>]+?)\\s*/>",
                options: [.dotMatchesLineSeparators],
            )
        } catch {
            preconditionFailure("Invalid media ref regex: \(error)")
        }
    }()

    static let dropQuote: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<DropQuote(?:\\s+([^>]+))?>(.*?)</DropQuote>",
                options: [.dotMatchesLineSeparators],
            )
        } catch {
            preconditionFailure("Invalid drop quote regex: \(error)")
        }
    }()

    static let sideNote: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<SideNote(?:\\s+([^>]+))?>(.*?)</SideNote>",
                options: [.dotMatchesLineSeparators],
            )
        } catch {
            preconditionFailure("Invalid side note regex: \(error)")
        }
    }()

    static let featureBox: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<FeatureBox(?:\\s+([^>]+))?>(.*?)</FeatureBox>",
                options: [.dotMatchesLineSeparators],
            )
        } catch {
            preconditionFailure("Invalid feature box regex: \(error)")
        }
    }()

    static let factGrid: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<FactGrid(?:\\s+[^>]*)?>(.*?)</FactGrid>",
                options: [.dotMatchesLineSeparators],
            )
        } catch {
            preconditionFailure("Invalid fact grid regex: \(error)")
        }
    }()

    static let fact: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<Fact\\s+([^>]+?)\\s*/>",
                options: [],
            )
        } catch {
            preconditionFailure("Invalid fact regex: \(error)")
        }
    }()

    static let timeline: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<Timeline(?:\\s+[^>]*)?>(.*?)</Timeline>",
                options: [.dotMatchesLineSeparators],
            )
        } catch {
            preconditionFailure("Invalid timeline regex: \(error)")
        }
    }()

    static let timelineItem: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<TimelineItem\\s+([^>]+)>(.*?)</TimelineItem>",
                options: [.dotMatchesLineSeparators],
            )
        } catch {
            preconditionFailure("Invalid timeline item regex: \(error)")
        }
    }()

    static let gallery: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<Gallery(?:\\s+[^>]*)?>(.*?)</Gallery>",
                options: [.dotMatchesLineSeparators],
            )
        } catch {
            preconditionFailure("Invalid gallery regex: \(error)")
        }
    }()

    static let galleryImage: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<GalleryImage\\s+([^>]+?)\\s*/>",
                options: [],
            )
        } catch {
            preconditionFailure("Invalid gallery image regex: \(error)")
        }
    }()

    static let fullBleed: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "<FullBleed\\s+([^>]+?)\\s*/>",
                options: [.dotMatchesLineSeparators],
            )
        } catch {
            preconditionFailure("Invalid full bleed regex: \(error)")
        }
    }()

    static let attributes: NSRegularExpression = {
        do {
            return try NSRegularExpression(
                pattern: "(\\w+)=\\\"([^\\\"]*)\\\"",
                options: [],
            )
        } catch {
            preconditionFailure("Invalid attribute regex: \(error)")
        }
    }()

    static let strippingPatterns: [NSRegularExpression] = [
        mediaRef,
        dropQuote,
        sideNote,
        featureBox,
        factGrid,
        timeline,
        gallery,
        fullBleed,
    ]
}

private enum DateFormatters {
    static let publishDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
