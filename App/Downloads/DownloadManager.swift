import Foundation
import GeckoView

struct DownloadRecord: Codable, Equatable, Identifiable {
    enum State: String, Codable { case active, complete, failed, cancelled }
    let id: UUID
    let sourceURL: String
    var localPath: String
    var filename: String
    var mimeType: String?
    var expectedBytes: Int64?
    var receivedBytes: Int64
    var state: State
    let startedAt: Date
}

final class DownloadManager {
    static let shared = DownloadManager()
    private let store = AtomicJSONStore<[DownloadRecord]>(filename: "downloads.json")
    private(set) var records: [DownloadRecord]
    private var lastProgressPersistence = Date.distantPast
    var onChange: (() -> Void)?

    private init() { records = store.load(default: []) }

    func accept(_ response: ExternalResponseInfo) -> Bool {
        guard !response.localFilePath.isEmpty else { return false }
        let name = response.filename?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = URL(string: response.url)?.lastPathComponent
        let filename = sanitize((name?.isEmpty == false ? name : fallback) ?? "Download")
        records.insert(DownloadRecord(
            id: UUID(), sourceURL: response.url, localPath: response.localFilePath,
            filename: filename, mimeType: response.mimeType,
            expectedBytes: response.contentLength, receivedBytes: 0,
            state: .active, startedAt: Date()
        ), at: 0)
        persist()
        return true
    }

    func update(path: String, bytes: Int64) -> Bool {
        guard let index = records.firstIndex(where: { $0.localPath == path && $0.state == .active }) else { return false }
        records[index].receivedBytes = max(records[index].receivedBytes, bytes)
        let now = Date()
        if now.timeIntervalSince(lastProgressPersistence) >= 1 {
            lastProgressPersistence = now
            persist()
        } else {
            notifyChange()
        }
        return true
    }

    func complete(path: String, succeeded: Bool) {
        guard let index = records.firstIndex(where: { $0.localPath == path }) else { return }
        guard succeeded else { records[index].state = .failed; persist(); return }
        let destination = uniqueDestination(filename: records[index].filename)
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.moveItem(at: URL(fileURLWithPath: path), to: destination)
            records[index].localPath = destination.path
            records[index].state = .complete
        } catch {
            records[index].state = .failed
        }
        persist()
    }

    func cancel(_ record: DownloadRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        try? FileManager.default.removeItem(atPath: records[index].localPath)
        records[index].state = .cancelled
        persist()
    }

    func remove(_ record: DownloadRecord, deleteFile: Bool) {
        if deleteFile { try? FileManager.default.removeItem(atPath: record.localPath) }
        records.removeAll { $0.id == record.id }
        persist()
    }

    private func uniqueDestination(filename: String) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("Downloads", isDirectory: true)
        var destination = directory.appendingPathComponent(filename)
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            let base = (filename as NSString).deletingPathExtension
            let ext = (filename as NSString).pathExtension
            destination = directory.appendingPathComponent("\(base) \(suffix)\(ext.isEmpty ? "" : ".\(ext)")")
            suffix += 1
        }
        return destination
    }

    private func sanitize(_ value: String) -> String {
        value.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
    }

    private func persist() {
        records = Array(records.prefix(1_000))
        store.save(records)
        notifyChange()
    }

    private func notifyChange() { DispatchQueue.main.async { self.onChange?() } }
}
