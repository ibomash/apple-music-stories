import Combine
import Foundation

struct DiagnosticLogEntry: Codable, Equatable {
    let timestamp: Date
    let event: String
    let message: String?
    let metadata: [String: String]?
}

@MainActor
protocol DiagnosticLogging: AnyObject {
    func log(event: String, message: String?, metadata: [String: String])
}

actor DiagnosticLogStore {
    private let fileManager: FileManager
    private let directoryURL: URL
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let retentionInterval: TimeInterval

    init(
        baseDirectoryURL: URL? = nil,
        fileManager: FileManager = .default,
        fileName: String = "diagnostic-logs.jsonl",
        retentionInterval: TimeInterval = 24 * 60 * 60
    ) {
        self.fileManager = fileManager
        self.retentionInterval = retentionInterval
        let rootURL = baseDirectoryURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directoryURL = rootURL.appendingPathComponent("Diagnostics", isDirectory: true)
        fileURL = directoryURL.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func append(_ entry: DiagnosticLogEntry) async {
        ensureDirectory()
        guard let lineData = encodeLine(entry) else {
            return
        }
        if fileManager.fileExists(atPath: fileURL.path) {
            guard let handle = try? FileHandle(forWritingTo: fileURL) else {
                return
            }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: lineData)
                try handle.close()
            } catch {
                try? handle.close()
            }
        } else {
            try? lineData.write(to: fileURL, options: .atomic)
        }
        await prune(keepingAfter: Date().addingTimeInterval(-retentionInterval))
    }

    func pruneToRetention() async {
        await prune(keepingAfter: Date().addingTimeInterval(-retentionInterval))
    }

    func clear() async {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        try? fileManager.removeItem(at: fileURL)
    }

    func hasContent() async -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? NSNumber else {
            return false
        }
        return size.intValue > 0
    }

    func export() async -> URL? {
        await pruneToRetention()
        guard await hasContent() else {
            return nil
        }
        let exportURL = fileManager.temporaryDirectory
            .appendingPathComponent("diagnostic-logs-\(Self.exportDateFormatter.string(from: Date())).jsonl")
        try? fileManager.removeItem(at: exportURL)
        do {
            try fileManager.copyItem(at: fileURL, to: exportURL)
            return exportURL
        } catch {
            return nil
        }
    }

    func readEntries() async -> [DiagnosticLogEntry] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8), content.isEmpty == false else {
            return []
        }
        return content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line in
                let data = Data(line.utf8)
                return try? decoder.decode(DiagnosticLogEntry.self, from: data)
            }
    }

    private func ensureDirectory() {
        guard fileManager.fileExists(atPath: directoryURL.path) == false else {
            return
        }
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func prune(keepingAfter cutoff: Date) async {
        let entries = await readEntries().filter { $0.timestamp >= cutoff }
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        guard entries.isEmpty == false else {
            try? fileManager.removeItem(at: fileURL)
            return
        }
        var output = Data()
        for entry in entries {
            if let line = encodeLine(entry) {
                output.append(line)
            }
        }
        guard output.isEmpty == false else {
            try? fileManager.removeItem(at: fileURL)
            return
        }
        try? output.write(to: fileURL, options: .atomic)
    }

    private func encodeLine(_ entry: DiagnosticLogEntry) -> Data? {
        guard let data = try? encoder.encode(entry) else {
            return nil
        }
        var line = data
        line.append(0x0A)
        return line
    }

    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

@MainActor
final class DiagnosticLogManager: ObservableObject, DiagnosticLogging {
    @Published var isEnabled: Bool {
        didSet {
            if isEnabled != oldValue {
                handleEnabledChange()
            }
        }
    }
    @Published private(set) var hasLogs: Bool = false

    private let store: DiagnosticLogStore
    private let defaults: UserDefaults
    private let enabledKey: String

    init(
        store: DiagnosticLogStore = DiagnosticLogStore(),
        defaults: UserDefaults = .standard,
        enabledKey: String = "diagnostic-logging-enabled"
    ) {
        self.store = store
        self.defaults = defaults
        self.enabledKey = enabledKey
        isEnabled = defaults.bool(forKey: enabledKey)
        Task {
            await bootstrap()
        }
    }

    func log(event: String, message: String? = nil, metadata: [String: String] = [:]) {
        guard isEnabled else {
            return
        }
        let entry = DiagnosticLogEntry(
            timestamp: Date(),
            event: event,
            message: message,
            metadata: metadata.isEmpty ? nil : metadata
        )
        Task {
            await store.append(entry)
            await refreshHasLogs()
        }
    }

    func prepareExport() async -> URL? {
        let url = await store.export()
        await refreshHasLogs()
        return url
    }

    private func bootstrap() async {
        if isEnabled {
            await store.pruneToRetention()
        } else {
            await store.clear()
        }
        await refreshHasLogs()
    }

    private func refreshHasLogs() async {
        let hasContent = await store.hasContent()
        if hasLogs != hasContent {
            hasLogs = hasContent
        }
    }

    private func handleEnabledChange() {
        defaults.set(isEnabled, forKey: enabledKey)
        Task {
            if isEnabled {
                await store.pruneToRetention()
                await refreshHasLogs()
                log(event: "logging_enabled")
            } else {
                await store.clear()
                await refreshHasLogs()
            }
        }
    }
}
