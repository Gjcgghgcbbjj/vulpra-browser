import Dispatch
import Foundation
import os

/// Host-process memory pressure observer.
///
/// UIKit's `didReceiveMemoryWarning` only fires close to the critical
/// threshold, which is too late for the App layer to reclaim background tabs
/// and prevent the content process from being selected by jetsam. Registering
/// a `dispatch_source_memorypressure` source surfaces the earlier `.warning`
/// level so the App can downgrade/suspend background work before the system
/// escalates. The source observes the *host* process (the Vulpra App), which
/// is the process whose footprint the App layer can actually control; the
/// Gecko engine host (EngineProcess.appex) already has its own in-process
/// watcher (AvailableMemoryWatcherIOS) and is not modified here.
@MainActor
final class MemoryPressureMonitor {
    private let handler: (EngineRuntimeMemoryPressure) -> Void
    private var source: DispatchSourceMemoryPressure?

    init(handler: @escaping (EngineRuntimeMemoryPressure) -> Void) {
        self.handler = handler
    }

    func start() {
        guard source == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            let flags = source.data
            let level: EngineRuntimeMemoryPressure =
                flags.contains(.critical) ? .critical : .warning
            Task { @MainActor [weak self] in
                self?.handler(level)
            }
        }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
