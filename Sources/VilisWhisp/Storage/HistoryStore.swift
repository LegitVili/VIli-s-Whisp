import Foundation
import Combine

struct HistoryEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var appName: String
    var bundleId: String
    var language: String?
    var raw: String
    var clean: String
    var commandMode: Bool
}

/// Cronologia su file JSONL in ~/Library/Application Support/VilisWhisp/history.jsonl
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [HistoryEntry] = []
    private let fileURL: URL
    private let queue = DispatchQueue(label: "it.vili.whisp.history")
    private let maxEntries = 2000

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("VilisWhisp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.jsonl")
        load()
    }

    private func load() {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = text.split(separator: "\n").compactMap { line -> HistoryEntry? in
            guard let d = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(HistoryEntry.self, from: d)
        }
        entries = Array(parsed.suffix(maxEntries)).reversed()
    }

    func append(_ entry: HistoryEntry) {
        entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries.removeLast(entries.count - maxEntries) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entry) else { return }
        let url = fileURL
        queue.async {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data + Data("\n".utf8))
            } else {
                try? (data + Data("\n".utf8)).write(to: url)
            }
        }
    }

    func clear() {
        entries.removeAll()
        let url = fileURL
        queue.async { try? FileManager.default.removeItem(at: url) }
    }

    func delete(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        rewrite()
    }

    private func rewrite() {
        let snapshot = entries.reversed()
        let url = fileURL
        queue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let lines = snapshot.compactMap { try? encoder.encode($0) }.map { String(decoding: $0, as: UTF8.self) }
            try? lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
