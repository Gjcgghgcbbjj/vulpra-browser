import Foundation

enum EngineChildProcessStage: Int32, Sendable {
    case requested = 1
    case extensionConnected = 2
    case bootstrapAcknowledged = 3
    case ipcConnected = 4
    case failed = 5
    case terminated = 6
}

enum EngineChildProcessFailureCode: Int32, Sendable {
    case none = 0
    case extensionStart = 1
    case xpcTransport = 2
    case bootstrapReply = 3
    case processLaunch = 4
    case ipcBeforeConnection = 5
    case terminatedBeforeOutcome = 6
    case invalidTransition = 7
}

struct EngineChildProcessEvent: Equatable, Sendable {
    let launchID: UInt64
    let childID: Int32
    let processIdentifier: Int32?
    let processType: String
    let stage: EngineChildProcessStage
    let monotonicTimestampNanoseconds: UInt64
    let failureCode: EngineChildProcessFailureCode
    let reason: String?
}

struct EngineChildProcessLifecycle {
    enum Outcome: Equatable {
        case connected
        case failed(EngineChildProcessFailureCode)
    }

    struct Record: Equatable {
        let childID: Int32
        let processType: String
        var processIdentifier: Int32?
        var lastStage: EngineChildProcessStage
        var lastTimestampNanoseconds: UInt64
        var outcome: Outcome?
        var terminated: Bool
    }

    private(set) var events: [EngineChildProcessEvent] = []
    private(set) var failures: [EngineFailure] = []
    private var records: [UInt64: Record] = [:]

    var openLaunchIDs: [UInt64] {
        records.compactMap { launchID, record in record.terminated ? nil : launchID }.sorted()
    }

    func record(for launchID: UInt64) -> Record? { records[launchID] }

    @discardableResult
    mutating func accept(_ event: EngineChildProcessEvent) -> EngineFailure? {
        guard let validationFailure = validate(event) else {
            return apply(event)
        }
        failures.append(validationFailure)
        return validationFailure
    }

    @discardableResult
    mutating func rejectUnknownStage(_ rawStage: Int32, launchID: UInt64) -> EngineFailure {
        let failure = EngineFailure(
            code: "engine-child-invalid-transition",
            message: "Unknown child lifecycle stage \(rawStage) for launch \(launchID)",
            isRecoverable: true
        )
        failures.append(failure)
        return failure
    }

    private func validate(_ event: EngineChildProcessEvent) -> EngineFailure? {
        guard event.launchID > 0, event.childID > 0,
              !event.processType.isEmpty, event.processType.utf8.count <= 64,
              event.monotonicTimestampNanoseconds > 0 else {
            return invalid(event, "invalid identity or timestamp")
        }
        if event.stage == .failed {
            guard event.failureCode != .none else {
                return invalid(event, "failed stage has no failure code")
            }
            if let reason = event.reason {
                let lowered = reason.lowercased()
                guard reason.utf8.count <= 160,
                      !lowered.contains("://"), !lowered.contains("www.") else {
                    return invalid(event, "failure reason is not bounded diagnostic text")
                }
            }
        } else if event.failureCode != .none || event.reason != nil {
            return invalid(event, "non-failed stage carries failure data")
        }
        return nil
    }

    private mutating func apply(_ event: EngineChildProcessEvent) -> EngineFailure? {
        guard var record = records[event.launchID] else {
            guard event.stage == .requested else {
                return storeInvalid(event, "first stage is not requested")
            }
            records[event.launchID] = Record(
                childID: event.childID,
                processType: event.processType,
                processIdentifier: event.processIdentifier,
                lastStage: event.stage,
                lastTimestampNanoseconds: event.monotonicTimestampNanoseconds,
                outcome: nil,
                terminated: false
            )
            events.append(event)
            return nil
        }

        guard record.childID == event.childID, record.processType == event.processType else {
            return storeInvalid(event, "launch identity changed")
        }
        guard !record.terminated else {
            return storeInvalid(event, "event followed termination")
        }
        guard event.monotonicTimestampNanoseconds > record.lastTimestampNanoseconds else {
            return storeInvalid(event, "timestamp did not advance")
        }
        guard event.stage != record.lastStage else {
            return storeInvalid(event, "duplicate stage")
        }

        let expectedNext: EngineChildProcessStage?
        switch record.lastStage {
        case .requested: expectedNext = .extensionConnected
        case .extensionConnected: expectedNext = .bootstrapAcknowledged
        case .bootstrapAcknowledged: expectedNext = .ipcConnected
        case .ipcConnected, .failed: expectedNext = .terminated
        case .terminated: expectedNext = nil
        }

        if event.stage == .failed {
            guard record.outcome == nil, record.lastStage.rawValue < EngineChildProcessStage.ipcConnected.rawValue else {
                return storeInvalid(event, "failure followed an outcome")
            }
            record.outcome = .failed(event.failureCode)
        } else if event.stage == .terminated, record.outcome == nil {
            let failure = EngineFailure(
                code: "engine-child-terminated-before-outcome",
                message: "Child launch \(event.launchID) terminated before connection",
                isRecoverable: true
            )
            record.outcome = .failed(.terminatedBeforeOutcome)
            failures.append(failure)
            record.lastStage = .terminated
            record.lastTimestampNanoseconds = event.monotonicTimestampNanoseconds
            record.processIdentifier = event.processIdentifier ?? record.processIdentifier
            record.terminated = true
            records[event.launchID] = record
            events.append(event)
            return failure
        } else if event.stage != expectedNext {
            return storeInvalid(event, "stage is regressive or skipped")
        } else if event.stage == .ipcConnected {
            guard record.outcome == nil else {
                return storeInvalid(event, "connection followed an outcome")
            }
            record.outcome = .connected
        }

        record.lastStage = event.stage
        record.lastTimestampNanoseconds = event.monotonicTimestampNanoseconds
        record.processIdentifier = event.processIdentifier ?? record.processIdentifier
        record.terminated = event.stage == .terminated
        records[event.launchID] = record
        events.append(event)

        if event.stage == .failed {
            let failure = childFailure(event)
            failures.append(failure)
            return failure
        }
        if event.stage == .terminated, record.outcome == .connected {
            let failure = EngineFailure(
                code: "engine-child-terminated",
                message: "Connected child launch \(event.launchID) terminated",
                isRecoverable: true
            )
            failures.append(failure)
            return failure
        }
        return nil
    }

    private func invalid(_ event: EngineChildProcessEvent, _ detail: String) -> EngineFailure {
        EngineFailure(
            code: "engine-child-invalid-transition",
            message: "Invalid child launch \(event.launchID): \(detail)",
            isRecoverable: true
        )
    }

    private mutating func storeInvalid(
        _ event: EngineChildProcessEvent, _ detail: String
    ) -> EngineFailure {
        let failure = invalid(event, detail)
        failures.append(failure)
        return failure
    }

    private func childFailure(_ event: EngineChildProcessEvent) -> EngineFailure {
        EngineFailure(
            code: "engine-child-\(failureName(event.failureCode))",
            message: "Child launch \(event.launchID) failed during \(failureName(event.failureCode))",
            isRecoverable: true
        )
    }

    private func failureName(_ code: EngineChildProcessFailureCode) -> String {
        switch code {
        case .none: "none"
        case .extensionStart: "extension-start"
        case .xpcTransport: "xpc-transport"
        case .bootstrapReply: "bootstrap-reply"
        case .processLaunch: "process-launch"
        case .ipcBeforeConnection: "ipc-before-connection"
        case .terminatedBeforeOutcome: "terminated-before-outcome"
        case .invalidTransition: "invalid-transition"
        }
    }
}
