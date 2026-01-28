@testable import MusicStoryRenderer
import Foundation
import XCTest

final class DiagnosticLoggingTests: XCTestCase {
    func testAppendWritesEntry() async throws {
        let tempRoot = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let store = DiagnosticLogStore(baseDirectoryURL: tempRoot)

        let entry = DiagnosticLogEntry(
            timestamp: Date(),
            event: "story_loaded",
            message: "ok",
            metadata: ["story_id": "sample"]
        )
        await store.append(entry)

        let entries = await store.readEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.event, "story_loaded")
    }

    func testRetentionDropsOldEntry() async throws {
        let tempRoot = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let store = DiagnosticLogStore(baseDirectoryURL: tempRoot)

        let oldEntry = DiagnosticLogEntry(
            timestamp: Date().addingTimeInterval(-25 * 60 * 60),
            event: "old_entry",
            message: nil,
            metadata: nil
        )
        await store.append(oldEntry)

        let entries = await store.readEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    func testExportCreatesCopy() async throws {
        let tempRoot = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        let store = DiagnosticLogStore(baseDirectoryURL: tempRoot)

        let entry = DiagnosticLogEntry(timestamp: Date(), event: "export_test", message: nil, metadata: nil)
        await store.append(entry)

        let exportURL = await store.export()
        XCTAssertNotNil(exportURL)
        if let exportURL {
            let data = try Data(contentsOf: exportURL)
            XCTAssertFalse(data.isEmpty)
            XCTAssertEqual(exportURL.pathExtension, "jsonl")
        }
    }

    private func makeTempDirectory() throws -> URL {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        return tempRoot
    }
}
