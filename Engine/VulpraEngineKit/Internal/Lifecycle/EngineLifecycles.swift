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

    mutating func becomeReady(_ capabilities: EngineCapabilities) {
        switch state {
        case .starting, .failed:
            state = .ready(capabilities)
        case .stopped, .ready:
            break
        }
    }

    mutating func fail(_ failure: EngineFailure) {
        switch state {
        case .ready:
            // Recoverable failures after ready are handled by sessions; only
            // non-recoverable runtime-main exits should poison the whole runtime.
            if !failure.isRecoverable {
                state = .failed(failure)
            }
        case .stopped, .starting, .failed:
            state = .failed(failure)
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
