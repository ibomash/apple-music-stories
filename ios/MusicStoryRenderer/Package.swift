// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MusicStoryRendererCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "MusicStoryRendererCore", targets: ["MusicStoryRendererCore"]),
    ],
    targets: [
        .target(
            name: "MusicStoryRendererCore",
            path: ".",
            exclude: [
                "App",
                "Playback",
                "Rendering",
                "Tests",
                "StoryDocumentStore.swift",
            ],
        ),
        .testTarget(
            name: "MusicStoryRendererCoreTests",
            dependencies: ["MusicStoryRendererCore"],
            path: "Tests/MusicStoryRendererCoreTests",
        ),
    ],
)
