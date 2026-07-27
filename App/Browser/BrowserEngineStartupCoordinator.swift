import Foundation
import VulpraEngineKit

@MainActor
final class BrowserEngineStartupCoordinator {
    private let runtime: any EngineRuntime
    private var task: Task<Void, Never>?

    init(runtime: any EngineRuntime) {
        self.runtime = runtime
    }

    func start(
        localeIdentifier: String,
        onReady: @escaping @MainActor () -> Void,
        onFailure: @escaping @MainActor (EngineFailure) -> Void
    ) {
        cancel()
        task = Task { @MainActor [runtime] in
            do {
                _ = try await runtime.start(configuration: EngineRuntimeConfiguration(
                    localeIdentifier: localeIdentifier
                ))
                guard !Task.isCancelled else { return }
                onReady()
            } catch let failure as EngineFailure {
                guard !Task.isCancelled else { return }
                onFailure(failure)
            } catch {
                guard !Task.isCancelled else { return }
                onFailure(EngineFailure(
                    code: "runtime-start", message: error.localizedDescription, isRecoverable: true
                ))
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
