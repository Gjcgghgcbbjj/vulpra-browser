import Foundation

/// Per-key latest-wins coalescing queue for fire-and-forget engine events.
///
/// The Gecko engine can emit bursts of high-frequency, callback-less events
/// during a page load (progress ticks, redirect locations, title/security
/// refreshes). Delivering every event through the main-actor observer chain
/// walks BrowserTab -> TabManager -> BrowserViewController -> chrome updates
/// once per event, which contributes main-thread layout work during the exact
/// window the user is scrolling. This coalescer collapses bursts of the same
/// event kind to the latest payload while preserving first-arrival order
/// between different kinds, so observers still observe the same final state
/// with a fraction of the main-thread deliveries.
///
/// Delivery contract (enforced by VulpraEngineSession):
/// - Only callback-less events are ever recorded here; callback-carrying and
///   state-transition events are delivered immediately.
/// - Pending coalesced events are flushed before any critical event
///   (PageStart/PageStop/ContentCrash/ContentKill/OnLoadError/...), so engine
///   ordering (location before pageCompleted) is preserved.
@MainActor
struct EngineEventCoalescer {
    /// A pending coalesced event, delivered in first-arrival order.
    struct Item {
        let kind: String
        let payload: [String: Any]
    }

    private struct Entry {
        var payload: [String: Any]
    }

    /// First-arrival order of pending kinds.
    private var kinds: [String] = []
    private var entries: [String: Entry] = [:]

    /// Number of events suppressed by latest-wins replacement. Exposed for the
    /// per-navigation `engine_event_stats` evidence line.
    private(set) var coalescedCount = 0

    var isEmpty: Bool { entries.isEmpty }

    /// Records a fire-and-forget event. If a pending entry for the same kind
    /// already exists, replaces its payload with the latest one and returns
    /// true (the earlier event was coalesced away). Otherwise appends a new
    /// pending item in first-arrival order and returns false.
    @discardableResult
    mutating func record(kind: String, payload: [String: Any]) -> Bool {
        if var entry = entries[kind] {
            entry.payload = payload
            entries[kind] = entry
            coalescedCount += 1
            return true
        }
        entries[kind] = Entry(payload: payload)
        kinds.append(kind)
        return false
    }

    /// Returns all pending items in first-arrival order and clears the queue.
    mutating func drain() -> [Item] {
        let items = kinds.map { kind in Item(kind: kind, payload: entries[kind]!.payload) }
        kinds.removeAll()
        entries.removeAll()
        return items
    }
}
