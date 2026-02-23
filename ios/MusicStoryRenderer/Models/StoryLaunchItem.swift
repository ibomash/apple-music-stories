import Foundation

enum StoryLaunchSource: String, Hashable, Codable {
    case bundled
    case savedRemote
    case recentLocal

    var displayTitle: String {
        switch self {
        case .bundled:
            "Bundled"
        case .savedRemote:
            "Saved"
        case .recentLocal:
            "Recent"
        }
    }
}

struct StoryMetadataSnapshot: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String?
    let authors: [String]
    let publishDate: Date
    let tags: [String]
    let heroImage: StoryHeroImage?
    let accentColor: String?

    init(document: StoryDocument) {
        id = document.id
        title = document.title
        subtitle = document.subtitle
        authors = document.authors
        publishDate = document.publishDate
        tags = document.tags
        heroImage = document.heroImage
        accentColor = document.accentColor
    }
}

struct StoryLaunchItem: Identifiable, Hashable {
    let id: String
    let metadata: StoryMetadataSnapshot
    let source: StoryLaunchSource
    let sourceURL: URL?
    let bookmarkData: Data?
    let lastOpened: Date?
}

enum StoryDeepLink {
    static let scheme = "apple-music-stories"
    private static let storyRoute = "story"

    static func url(for item: StoryLaunchItem) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = storyRoute
        components.path = "/\(storyCode(for: item))"
        return components.url
    }

    static func storyCode(for item: StoryLaunchItem) -> String {
        StoryDeepLinkCodeBuilder.code(for: item)
    }

    static func storyCode(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme else {
            return nil
        }

        if url.host?.lowercased() == storyRoute {
            guard let rawCode = url.pathSegments.first else {
                return nil
            }
            return normalizeStoryCode(rawCode)
        }

        if url.host?.isEmpty ?? true {
            let segments = url.pathSegments
            guard segments.count >= 2, segments[0].lowercased() == storyRoute else {
                return nil
            }
            return normalizeStoryCode(segments[1])
        }

        return nil
    }

    static func normalizeStoryCode(_ rawCode: String) -> String? {
        let trimmed = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }
        let normalized = trimmed.uppercased()
        guard normalized.hasPrefix("S1-") else {
            return nil
        }

        let payload = normalized.dropFirst(3)
        guard payload.count == 14, let sourceCode = payload.first else {
            return nil
        }
        guard StoryDeepLinkCodeBuilder.validSourceCodes.contains(sourceCode) else {
            return nil
        }

        let hashComponent = payload.dropFirst()
        guard hashComponent.allSatisfy(StoryDeepLinkCodeBuilder.allowedCodeCharacters.contains) else {
            return nil
        }

        return normalized
    }
}

private enum StoryDeepLinkCodeBuilder {
    static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    static let allowedCodeCharacters = Set(alphabet)
    static let validSourceCodes: Set<Character> = ["B", "R", "L"]

    static func code(for item: StoryLaunchItem) -> String {
        let sourceCode = sourceCode(for: item.source)
        let hash = fnv1a64(canonicalKey(for: item))
        let encodedHash = base32(value: hash, minimumLength: 13)
        return "S1-\(sourceCode)\(encodedHash)"
    }

    private static func sourceCode(for source: StoryLaunchSource) -> Character {
        switch source {
        case .bundled:
            return "B"
        case .savedRemote:
            return "R"
        case .recentLocal:
            return "L"
        }
    }

    private static func canonicalKey(for item: StoryLaunchItem) -> String {
        [
            item.source.rawValue,
            item.metadata.id,
            canonicalSourceIdentifier(for: item),
        ].joined(separator: "|")
    }

    private static func canonicalSourceIdentifier(for item: StoryLaunchItem) -> String {
        guard let sourceURL = item.sourceURL else {
            return item.id
        }
        switch item.source {
        case .bundled:
            return bundledLocator(for: sourceURL)
        case .savedRemote:
            return sourceURL.absoluteString
        case .recentLocal:
            if sourceURL.isFileURL {
                return sourceURL.standardizedFileURL.path
            }
            return sourceURL.absoluteString
        }
    }

    private static func bundledLocator(for url: URL) -> String {
        if let storiesIndex = url.pathComponents.firstIndex(of: "stories") {
            let startIndex = storiesIndex + 1
            if startIndex < url.pathComponents.count {
                return url.pathComponents[startIndex...].joined(separator: "/")
            }
        }
        return url.lastPathComponent
    }

    private static func fnv1a64(_ value: String) -> UInt64 {
        let offsetBasis: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211
        var hash = offsetBasis
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return hash
    }

    private static func base32(value: UInt64, minimumLength: Int) -> String {
        if value == 0 {
            return String(repeating: "0", count: minimumLength)
        }
        var remaining = value
        var characters: [Character] = []
        while remaining > 0 {
            let index = Int(remaining % 32)
            characters.append(alphabet[index])
            remaining /= 32
        }
        let encoded = String(characters.reversed())
        if encoded.count >= minimumLength {
            return encoded
        }
        return String(repeating: "0", count: minimumLength - encoded.count) + encoded
    }
}

private extension URL {
    var pathSegments: [String] {
        path
            .split(separator: "/")
            .map(String.init)
    }
}
