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

struct RecentLocalStory: Codable, Equatable {
    let sourceURL: URL
    let bookmarkData: Data
    let metadata: StoryMetadataSnapshot
    let lastOpened: Date
}

protocol RecentLocalStoryStoring {
    func load() throws -> [RecentLocalStory]
    func save(_ stories: [RecentLocalStory]) throws
}

struct FileRecentLocalStoryStore: RecentLocalStoryStoring {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        let directoryURL = baseDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        fileURL = directoryURL
            .appendingPathComponent("stories", isDirectory: true)
            .appendingPathComponent("recent-local-stories.json")
    }

    func load() throws -> [RecentLocalStory] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([RecentLocalStory].self, from: data)
    }

    func save(_ stories: [RecentLocalStory]) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        let data = try JSONEncoder().encode(stories)
        try data.write(to: fileURL, options: [.atomic])
    }
}

protocol StoryRecencyStoring {
    func lastOpened(for key: String) -> Date?
    func update(key: String, lastOpened: Date) throws
}

struct FileStoryRecencyStore: StoryRecencyStoring {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        let directoryURL = baseDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        fileURL = directoryURL
            .appendingPathComponent("stories", isDirectory: true)
            .appendingPathComponent("story-recency.json")
    }

    func lastOpened(for key: String) -> Date? {
        (try? loadAll()[key]) ?? nil
    }

    func update(key: String, lastOpened: Date) throws {
        var entries = try loadAll()
        entries[key] = lastOpened
        try saveAll(entries)
    }

    private func loadAll() throws -> [String: Date] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([String: Date].self, from: data)
    }

    private func saveAll(_ entries: [String: Date]) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        let data = try JSONEncoder().encode(entries)
        try data.write(to: fileURL, options: [.atomic])
    }
}
