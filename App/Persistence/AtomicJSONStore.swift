import Foundation

struct AtomicJSONStore<Value: Codable> {
    private let url: URL
    private let queue: DispatchQueue
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String) {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Vulpra", isDirectory: true)
        url = root.appendingPathComponent(filename)
        queue = DispatchQueue(label: "com.vulpra.browser.store.\(filename)", qos: .utility)
        encoder.outputFormatting = [.sortedKeys]
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func load(default fallback: Value) -> Value {
        queue.sync {
            guard let data = try? Data(contentsOf: url) else { return fallback }
            return (try? decoder.decode(Value.self, from: data)) ?? fallback
        }
    }

    func save(_ value: Value) {
        queue.async { [encoder, url] in
            guard let data = try? encoder.encode(value) else { return }
            let temporary = url.appendingPathExtension("new")
            do {
                try data.write(to: temporary, options: .atomic)
                if FileManager.default.fileExists(atPath: url.path) {
                    _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
                } else {
                    try FileManager.default.moveItem(at: temporary, to: url)
                }
            } catch {
                try? FileManager.default.removeItem(at: temporary)
            }
        }
    }

    func remove() {
        queue.async { [url] in try? FileManager.default.removeItem(at: url) }
    }
}
