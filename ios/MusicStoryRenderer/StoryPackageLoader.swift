import Foundation

struct StoryPackage {
    let storyURL: URL
    let storyText: String
    let assetBaseURL: URL
}

protocol StoryPackageLoading {
    func loadStory(at url: URL) throws -> StoryPackage
}

enum StoryPackageLoaderError: LocalizedError {
    case invalidStoryURL(URL)
    case missingStoryFile(URL)
    case unreadableStory(URL)

    var errorDescription: String? {
        switch self {
        case let .invalidStoryURL(url):
            return "Invalid story URL: \(url.path)."
        case let .missingStoryFile(url):
            return "Missing story.mdx in \(url.path)."
        case let .unreadableStory(url):
            return "Unable to read story content at \(url.path)."
        }
    }
}

struct StoryPackageLoader: StoryPackageLoading {
    func loadStory(at url: URL) throws -> StoryPackage {
        var securityScopedAccess = false
        #if os(iOS) || os(macOS)
        if url.isFileURL {
            securityScopedAccess = url.startAccessingSecurityScopedResource()
        }
        #endif
        defer {
            #if os(iOS) || os(macOS)
            if securityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
            #endif
        }

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
