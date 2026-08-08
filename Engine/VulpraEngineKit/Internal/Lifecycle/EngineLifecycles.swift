import Foundation

struct EngineRuntimeLifecycle {
    private(set) var state: EngineRuntimeState = .stopped

    mutating func begin() -> Bool {
        switch state {
        case .stopped:
            state = .starting
            return true
        case .failed(let failure) where failure.isRecoverable:
            state = .starting
            return true
        case .starting, .ready, .failed:
            return false
        }
    }

    /// Transition to ready ONLY from .starting. A late `Vulpra:RuntimeReady`
    /// arriving after a terminal non-recoverable failure must not resurrect the
    /// runtime (terminal state is terminal). Returns true only when the
    /// transition actually happened.
    mutating func becomeReady(_ capabilities: EngineCapabilities) -> Bool {
        guard case .starting = state else { return false }
        state = .ready(capabilities)
        return true
    }

    mutating func fail(_ failure: EngineFailure) {
        switch state {
        case .ready:
            // Recoverable failures after ready are handled by sessions; only
            // non-recoverable runtime-main exits should poison the whole runtime.
            if !failure.isRecoverable {
                state = .failed(failure)
            }
        case .stopped, .starting:
            state = .failed(failure)
        case .failed:
            // Terminal failure already recorded; do not mask it with a later
            // failure (recoverable child failures must not hide the reason).
            break
        }
    }
}

struct EngineSessionLifecycle {
    private(set) var state: EngineSessionState = .closed

    mutating func beginOpen() -> Bool {
        switch state {
        case .closed, .failed:
            state = .opening
            return true
        case .opening, .open, .closing:
            return false
        }
    }

    mutating func becomeOpen() -> Bool {
        guard case .opening = state else { return false }
        state = .open
        return true
    }

    mutating func fail(_ failure: EngineFailure) {
        state = .failed(failure)
    }

    mutating func beginClose() -> Bool {
        switch state {
        case .closed, .closing:
            return false
        case .opening, .open, .failed:
            state = .closing
            return true
        }
    }

    mutating func finishClose() {
        state = .closed
    }
}
