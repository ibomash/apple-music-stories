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

    init(document: StoryDocument) {
        id = document.id
        title = document.title
        subtitle = document.subtitle
        authors = document.authors
        publishDate = document.publishDate
        tags = document.tags
        heroImage = document.heroImage
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
