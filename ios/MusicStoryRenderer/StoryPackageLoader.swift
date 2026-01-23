import Foundation

struct StoryPackage: Sendable {
    let storyURL: URL
    let storyText: String
    let assetBaseURL: URL
}

protocol StoryPackageLoading {
    func loadStory(at url: URL) throws -> StoryPackage
}

protocol HTTPDataLoading: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataLoading {}

enum RemoteStoryLoadError: LocalizedError, Equatable, Sendable {
    case invalidScheme
    case invalidExtension
    case invalidResponse
    case invalidStatusCode(Int)
    case emptyResponse
    case unreadableStory

    var errorDescription: String? {
        switch self {
        case .invalidScheme:
            "Story URLs must use http or https."
        case .invalidExtension:
            "Story URLs must point to a .mdx file."
        case .invalidResponse:
            "The server response was invalid."
        case let .invalidStatusCode(code):
            "The server returned status code \(code)."
        case .emptyResponse:
            "The story download was empty."
        case .unreadableStory:
            "Unable to read the downloaded story."
        }
    }
}

protocol RemoteStoryPackageLoading: Sendable {
    func loadStory(from url: URL) async throws -> StoryPackage
}

enum StoryPackageLoaderError: LocalizedError {
    case invalidStoryURL(URL)
    case missingStoryFile(URL)
    case unreadableStory(URL)

    var errorDescription: String? {
        switch self {
        case let .invalidStoryURL(url):
            "Invalid story URL: \(url.path)."
        case let .missingStoryFile(url):
            "Missing story.mdx in \(url.path)."
        case let .unreadableStory(url):
            "Unable to read story content at \(url.path)."
        }
    }
}

struct StoryPackageLoader: StoryPackageLoading {
    func loadStory(at url: URL) throws -> StoryPackage {
        let storyURL = try resolveStoryURL(from: url)
        guard let storyText = try? String(contentsOf: storyURL, encoding: .utf8) else {
            throw StoryPackageLoaderError.unreadableStory(storyURL)
        }
        let assetBaseURL = storyURL.deletingLastPathComponent()
        return StoryPackage(storyURL: storyURL, storyText: storyText, assetBaseURL: assetBaseURL)
    }

    private func resolveStoryURL(from url: URL) throws -> URL {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists else {
            throw StoryPackageLoaderError.invalidStoryURL(url)
        }

        if isDirectory.boolValue {
            let storyURL = url.appendingPathComponent("story.mdx")
            guard FileManager.default.fileExists(atPath: storyURL.path) else {
                throw StoryPackageLoaderError.missingStoryFile(url)
            }
            return storyURL
        }

        guard url.pathExtension.lowercased() == "mdx" else {
            throw StoryPackageLoaderError.invalidStoryURL(url)
        }
        return url
    }
}

struct RemoteStoryPackageLoader: RemoteStoryPackageLoading, Sendable {
    private let dataLoader: HTTPDataLoading

    init(dataLoader: HTTPDataLoading = URLSession.shared) {
        self.dataLoader = dataLoader
    }

    func loadStory(from url: URL) async throws -> StoryPackage {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw RemoteStoryLoadError.invalidScheme
        }
        guard url.pathExtension.lowercased() == "mdx" else {
            throw RemoteStoryLoadError.invalidExtension
        }
        let (data, response) = try await dataLoader.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteStoryLoadError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw RemoteStoryLoadError.invalidStatusCode(httpResponse.statusCode)
        }
        guard data.isEmpty == false else {
            throw RemoteStoryLoadError.emptyResponse
        }
        guard let storyText = String(data: data, encoding: .utf8) else {
            throw RemoteStoryLoadError.unreadableStory
        }
        let assetBaseURL = url.deletingLastPathComponent()
        return StoryPackage(storyURL: url, storyText: storyText, assetBaseURL: assetBaseURL)
    }
}
