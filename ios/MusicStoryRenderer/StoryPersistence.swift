import Foundation

struct PersistedRemoteStory: Codable, Equatable {
    let sourceURL: URL
    let storyText: String
    let savedAt: Date

    var assetBaseURL: URL {
        sourceURL.deletingLastPathComponent()
    }
}

protocol PersistedRemoteStoryStoring {
    func load() throws -> PersistedRemoteStory?
    func save(_ story: PersistedRemoteStory) throws
    func delete() throws
    func hasStory() -> Bool
}

struct FilePersistedRemoteStoryStore: PersistedRemoteStoryStoring {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        let directoryURL = baseDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        fileURL = directoryURL
            .appendingPathComponent("stories", isDirectory: true)
            .appendingPathComponent("remote-story.json")
    }

    func load() throws -> PersistedRemoteStory? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PersistedRemoteStory.self, from: data)
    }

    func save(_ story: PersistedRemoteStory) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        let data = try JSONEncoder().encode(story)
        try data.write(to: fileURL, options: [.atomic])
    }

    func delete() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        try fileManager.removeItem(at: fileURL)
    }

    func hasStory() -> Bool {
        fileManager.fileExists(atPath: fileURL.path)
    }
}
