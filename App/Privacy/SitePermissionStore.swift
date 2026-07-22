import Foundation
import GeckoView

struct SitePermissionRecord: Codable, Equatable, Identifiable {
    enum Decision: String, Codable { case allow, deny }
    let id: UUID
    let host: String
    let permission: String
    var decision: Decision
    var updatedAt: Date
}

final class SitePermissionStore {
    static let shared = SitePermissionStore()
    private let store = AtomicJSONStore<[SitePermissionRecord]>(filename: "site-permissions.json")
    private(set) var records: [SitePermissionRecord]
    private init() { records = store.load(default: []) }

    func decision(host: String, permission: String) -> SitePermissionRecord.Decision? {
        records.first { $0.host == host && $0.permission == permission }?.decision
    }

    func set(host: String, permission: String, decision: SitePermissionRecord.Decision) {
        records.removeAll { $0.host == host && $0.permission == permission }
        records.insert(SitePermissionRecord(id: UUID(), host: host, permission: permission,
                                            decision: decision, updatedAt: Date()), at: 0)
        records = Array(records.prefix(1_000))
        store.save(records)
    }

    func remove(_ record: SitePermissionRecord) { records.removeAll { $0.id == record.id }; store.save(records) }
    func clear() { records.removeAll(); store.save(records) }
}
