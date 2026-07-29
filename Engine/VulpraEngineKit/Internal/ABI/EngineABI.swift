import Foundation

final class EngineABIContext<Value: AnyObject>: NSObject {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

final class EngineABICallbackLease: @unchecked Sendable {
    typealias Resolver = @Sendable (AnyObject, Bool) -> Void

    private let lock = NSLock()
    private var resolver: Resolver?

    init(pointer: UnsafeMutableRawPointer) {
        resolver = { value, isError in
            engineABICallbackResolve(pointer, engineABIPointer(value), isError)
        }
    }

    init(resolver: @escaping Resolver) {
        self.resolver = resolver
    }

    deinit {
        finish(value: "callback abandoned" as NSString, isError: true)
    }

    func resolve(_ value: AnyObject, isError: Bool = false) {
        finish(value: value, isError: isError)
    }

    func cancel(_ message: String = "callback cancelled") {
        finish(value: message as NSString, isError: true)
    }

    private func finish(value: AnyObject, isError: Bool) {
        lock.lock()
        let action = resolver
        resolver = nil
        lock.unlock()
        action?(value, isError)
    }
}

func takeCallback(_ pointer: UnsafeMutableRawPointer?) -> EngineABICallbackLease? {
    pointer.map(EngineABICallbackLease.init(pointer:))
}

typealias EngineABIEventHandler = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeRawPointer, UnsafeRawPointer?, UnsafeMutableRawPointer?
) -> Void
typealias EngineABIChildProcessHandler = @convention(c) (
    UnsafeMutableRawPointer?, UInt64, Int32, Int32, UnsafeRawPointer, Int32,
    UInt64, Int32, UnsafeRawPointer?
) -> Void

@_silgen_name("VEKRuntimeCreate")
func engineABIRuntimeCreate(
    _ context: UnsafeMutableRawPointer?, _ eventHandler: EngineABIEventHandler,
    _ childProcessHandler: EngineABIChildProcessHandler?
) -> UnsafeMutableRawPointer?

@_silgen_name("VEKRuntimeMain")
func engineABIRuntimeMain(
    _ runtime: UnsafeMutableRawPointer, _ argc: Int32,
    _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> Int32

@_silgen_name("VEKRuntimeDispatch")
func engineABIRuntimeDispatch(
    _ runtime: UnsafeMutableRawPointer, _ type: UnsafeRawPointer,
    _ message: UnsafeRawPointer?
)

@_silgen_name("VEKWindowOpen")
func engineABIWindowOpen(
    _ runtime: UnsafeMutableRawPointer, _ identifier: UnsafeRawPointer,
    _ initialData: UnsafeRawPointer, _ privateMode: Bool,
    _ context: UnsafeMutableRawPointer?, _ handler: EngineABIEventHandler
) -> UnsafeMutableRawPointer?

@_silgen_name("VEKWindowView")
func engineABIWindowView(_ window: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?

@_silgen_name("VEKWindowDispatch")
func engineABIWindowDispatch(
    _ window: UnsafeMutableRawPointer, _ type: UnsafeRawPointer,
    _ message: UnsafeRawPointer?
)

@_silgen_name("VEKWindowClose")
func engineABIWindowClose(_ window: UnsafeMutableRawPointer)

@_silgen_name("VEKCallbackResolve")
func engineABICallbackResolve(
    _ callback: UnsafeMutableRawPointer, _ response: UnsafeRawPointer?, _ isError: Bool
)

@_silgen_name("VEKChildProcessStart")
func engineABIChildProcessStart(
    _ connection: UnsafeRawPointer, _ context: UnsafeMutableRawPointer?,
    _ handler: EngineABIEventHandler
) -> Bool

func engineABIPointer(_ object: AnyObject) -> UnsafeRawPointer {
    UnsafeRawPointer(Unmanaged.passUnretained(object).toOpaque())
}

func engineABIDictionaryPointer(_ value: [String: Any]) -> UnsafeRawPointer {
    engineABIPointer(value as NSDictionary)
}
