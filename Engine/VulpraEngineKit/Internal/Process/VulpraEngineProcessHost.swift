import Foundation

public enum VulpraEngineProcessHost {
    public static func start(connection: NSXPCConnection) -> Bool {
        let pointer = Unmanaged.passUnretained(connection).toOpaque()
        return engineABIChildProcessStart(UnsafeRawPointer(pointer), nil, vulpraProcessEventHandler)
    }
}

private let vulpraProcessEventHandler: EngineABIEventHandler = { _, _, _, callback in
    resolve(takeCallback(callback), value: NSNull())
}
