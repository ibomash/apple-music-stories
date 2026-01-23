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

        var frontMatterParser = FrontMatterParser(text: split.frontMatter)
        let values = frontMatterParser.parse()
        diagnostics.append(contentsOf: frontMatterParser.diagnostics)

        guard let frontMatter = mapFrontMatter(values, assetBaseURL: assetBaseURL, diagnostics: &diagnostics) else {
            return ParsedStory(document: nil, diagnostics: diagnostics)
        }

        var bodyDiagnostics: [ValidationDiagnostic] = []
        let sections = parseBody(
            split.body,
            sectionMetadata: frontMatter.sections,
            diagnostics: &bodyDiagnostics,
        )
        diagnostics.append(contentsOf: bodyDiagnostics)

        let hasErrors = diagnostics.contains { $0.severity == .error }
        let document = StoryDocument(
            schemaVersion: frontMatter.schemaVersion,
            id: frontMatter.id,
            title: frontMatter.title,
            subtitle: frontMatter.subtitle,
            authors: frontMatter.authors,
            editors: frontMatter.editors,
            publishDate: frontMatter.publishDate,
            tags: frontMatter.tags,
            locale: frontMatter.locale,
            heroImage: frontMatter.heroImage,
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
        assetBaseURL: URL?,
        diagnostics: inout [ValidationDiagnostic],
    ) -> FrontMatterData? {
        let resolver = StoryAssetResolver(baseURL: assetBaseURL)

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
        let authors = stringList("authors", from: values, required: true, diagnostics: &diagnostics)
        let editors = stringList("editors", from: values, required: false, diagnostics: &diagnostics)
        let publishDateValue = stringValue("publish_date", from: values, required: true, diagnostics: &diagnostics)
        let tags = stringList("tags", from: values, required: false, diagnostics: &diagnostics)
        let locale = stringValue("locale", from: values, required: false, diagnostics: &diagnostics)

        let publishDate = parsePublishDate(publishDateValue, diagnostics: &diagnostics)
        let heroImage = parseHeroImage(values, resolver: resolver, diagnostics: &diagnostics)
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
            authors: authors,
            editors: editors,
            publishDate: publishDate,
            tags: tags,
            locale: locale,
            heroImage: heroImage,
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
            let blocks = parseSectionBlocks(contentText, sectionId: sectionId, diagnostics: &diagnostics)

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

    private func parseSectionBlocks(
        _ contentText: String,
        sectionId: String,
        diagnostics: inout [ValidationDiagnostic],
    ) -> [StoryBlock] {
        let matches = Regex.mediaRef.matches(
            in: contentText,
            range: NSRange(contentText.startIndex..., in: contentText),
        )
        var blocks: [StoryBlock] = []
        var paragraphIndex = 0
        var mediaIndex = 0
        var lastIndex = contentText.startIndex

        func appendParagraphs(from text: String) {
            let paragraphs = splitParagraphs(text)
            for paragraph in paragraphs {
                let identifier = "\(sectionId)-paragraph-\(paragraphIndex)"
                paragraphIndex += 1
                blocks.append(.paragraph(id: identifier, text: paragraph))
            }
        }

        for match in matches {
            guard let matchRange = Range(match.range, in: contentText),
                  let attributeRange = Range(match.range(at: 1), in: contentText)
            else {
                continue
            }

            let leadingText = String(contentText[lastIndex ..< matchRange.lowerBound])
            appendParagraphs(from: leadingText)
            lastIndex = matchRange.upperBound

            let attributeText = String(contentText[attributeRange])
            let attributes = parseAttributes(from: attributeText)
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
        }

        let trailingText = String(contentText[lastIndex...])
        appendParagraphs(from: trailingText)

        let unsupportedContent = Regex.mediaRef.stringByReplacingMatches(
            in: contentText,
            range: NSRange(contentText.startIndex..., in: contentText),
            withTemplate: "",
        )
        if unsupportedContent.contains("<") {
            diagnostics.append(.warning(
                code: "unsupported_html",
                message: "Unsupported HTML or components found in section '\(sectionId)'.",
            ))
        }

        return blocks
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
    let authors: [String]
    let editors: [String]
    let publishDate: Date
    let tags: [String]
    let locale: String?
    let heroImage: StoryHeroImage?
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
                case "sections", "media":
                    values[key] = parseListOfMaps(indentationLevel: 2)
                case "authors", "editors", "tags":
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
                pattern: "<MediaRef\\s+([^/>]+?)\\s*/>",
                options: [.dotMatchesLineSeparators],
            )
        } catch {
            preconditionFailure("Invalid media ref regex: \(error)")
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
