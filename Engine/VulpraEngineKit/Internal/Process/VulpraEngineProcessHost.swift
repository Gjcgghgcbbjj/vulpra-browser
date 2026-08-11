import Foundation

public enum VulpraEngineProcessHost {
    public enum StartError: Error, LocalizedError {
        case unavailablePrivateConnectionBridge
        case missingNativeXPCHandle

        public var errorDescription: String? {
            switch self {
            case .unavailablePrivateConnectionBridge:
                return "NSXPCConnection native bridge is unavailable"
            case .missingNativeXPCHandle:
                return "NSXPCConnection has no native XPC handle"
            }
        }
    }

    public static func start(connection: NSXPCConnection) throws {
        guard connection.responds(to: NSSelectorFromString("_xpcConnection")) else {
            throw StartError.unavailablePrivateConnectionBridge
        }
        let pointer = Unmanaged.passUnretained(connection).toOpaque()
        guard engineABIChildProcessStart(
            UnsafeRawPointer(pointer), nil, vulpraProcessEventHandler
        ) else {
            throw StartError.missingNativeXPCHandle
        }
    }
}

private let vulpraProcessEventHandler: EngineABIEventHandler = { _, _, _, callback in
    resolve(takeCallback(callback), value: NSNull())
}
