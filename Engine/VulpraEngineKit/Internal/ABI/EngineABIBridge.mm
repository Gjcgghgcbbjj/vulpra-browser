#import "EngineABIBridge.h"

extern "C" {
#import <GeckoView/GeckoViewSwiftSupport.h>
#import <GeckoView/IOSBootstrap.h>
}
#import <UIKit/UIKit.h>
#import <xpc/xpc.h>
#import <objc/runtime.h>
#import <os/log.h>

@class VEKDispatcher;

@interface VEKCallback : NSObject
@property(nonatomic, weak) VEKDispatcher *owner;
@property(nonatomic, strong) id<EventCallback> callback;
@property(nonatomic) BOOL completed;
- (void)complete:(id _Nullable)value error:(BOOL)error;
@end

@interface VEKDispatcher : NSObject <SwiftEventDispatcher>
@property(nonatomic, strong, nullable) id<GeckoEventDispatcher> engine;
@property(nonatomic, strong, nullable) NSMutableArray<NSArray *> *queue;
@property(nonatomic, strong) NSMutableSet<VEKCallback *> *callbacks;
@property(nonatomic, strong, nullable) id context;
@property(nonatomic) VulpraEngineEventHandler handler;
- (instancetype)initWithContext:(id _Nullable)context
                         handler:(VulpraEngineEventHandler)handler;
- (void)send:(NSString *)type message:(id _Nullable)message;
- (void)send:(NSString *)type
      message:(id _Nullable)message
     callback:(id<EventCallback> _Nullable)callback;
- (void)removeCallback:(VEKCallback *)callback;
- (void)invalidate;
@end

@implementation VEKCallback
- (void)complete:(id)value error:(BOOL)error {
  @synchronized(self) {
    if (_completed) return;
    _completed = YES;
  }
  if (error) {
    [_callback sendError:value];
  } else {
    [_callback sendSuccess:value];
  }
  [_owner removeCallback:self];
  _callback = nil;
}
@end

// Bridges a C callback supplied through the ABI into the Gecko
// EventCallback protocol for Swift->Gecko request/response messaging.
// The response/error values are borrowed for the duration of the call; the
// callback fires at most once (first response wins).
@interface VEKGeckoCallback : NSObject <EventCallback>
@property(nonatomic) VulpraEngineCallbackHandler handler;
@property(nonatomic) void *context;
- (instancetype)initWithHandler:(VulpraEngineCallbackHandler)handler
                        context:(void *)context;
@end

@implementation VEKGeckoCallback
- (instancetype)initWithHandler:(VulpraEngineCallbackHandler)handler
                        context:(void *)context {
  self = [super init];
  if (self) {
    _handler = handler;
    _context = context;
  }
  return self;
}

- (void)sendSuccess:(id)response {
  VulpraEngineCallbackHandler handler = _handler;
  void *context = _context;
  _handler = nil;
  if (handler) {
    handler(context, response ? (__bridge const void *)response : nullptr,
            nullptr);
  }
}

- (void)sendError:(id)error {
  VulpraEngineCallbackHandler handler = _handler;
  void *context = _context;
  _handler = nil;
  if (handler) {
    handler(context, nullptr,
            error ? (__bridge const void *)error : nullptr);
  }
}
@end

@implementation VEKDispatcher
- (instancetype)initWithContext:(id)context
                         handler:(VulpraEngineEventHandler)handler {
  self = [super init];
  if (self) {
    _context = context;
    _handler = handler;
    _queue = [NSMutableArray array];
    _callbacks = [NSMutableSet set];
  }
  return self;
}

- (void)attach:(id<GeckoEventDispatcher>)engine {
  @synchronized(self) {
    _engine = engine;
  }
}

- (void)dispatchToSwift:(NSString *)type
                message:(id)message
               callback:(id<EventCallback>)callback {
  VEKCallback *box = nil;
  if (callback) {
    box = [VEKCallback new];
    box.owner = self;
    box.callback = callback;
  }
  VulpraEngineEventHandler handler = nullptr;
  id context = nil;
  @synchronized(self) {
    handler = _handler;
    context = _context;
    if (handler && context && box) {
      [_callbacks addObject:box];
    }
  }
  if (handler && context) {
    void *ownedCallback = box ? (__bridge_retained void *)box : nullptr;
    handler((__bridge void *)context, (__bridge const void *)type,
            (__bridge const void *)message, ownedCallback);
  } else {
    [box complete:@"dispatcher unavailable" error:YES];
  }
}

- (BOOL)hasListener:(NSString *)type {
  @synchronized(self) {
    return _handler != nullptr && _context != nil;
  }
}

- (void)activate {
  NSArray<NSArray *> *pending;
  id<GeckoEventDispatcher> engine;
  VulpraEngineEventHandler handler;
  id context;
  @synchronized(self) {
    pending = [_queue copy];
    _queue = nil;
    engine = _engine;
    handler = _handler;
    context = _context;
  }
  for (NSArray *item in pending) {
    id queuedCallback = item.count > 2 ? item[2] : nil;
    if (queuedCallback == NSNull.null) queuedCallback = nil;
    [engine dispatchToGecko:item[0]
                    message:item[1] == NSNull.null ? nil : item[1]
                   callback:queuedCallback];
  }
  if (handler && context) {
    NSString *ready = @"Vulpra:RuntimeReady";
    handler((__bridge void *)context, (__bridge const void *)ready, nullptr,
            nullptr);
  }
}

- (void)send:(NSString *)type message:(id)message {
  [self send:type message:message callback:nil];
}

- (void)send:(NSString *)type
      message:(id)message
     callback:(id<EventCallback>)callback {
  id<GeckoEventDispatcher> engine;
  @synchronized(self) {
    if (_queue) {
      [_queue addObject:@[ type, message ?: NSNull.null,
                           callback ?: NSNull.null ]];
      return;
    }
    engine = _engine;
  }
  [engine dispatchToGecko:type message:message callback:callback];
}

- (void)removeCallback:(VEKCallback *)callback {
  @synchronized(self) {
    [_callbacks removeObject:callback];
  }
}

- (void)invalidate {
  NSArray<VEKCallback *> *callbacks;
  @synchronized(self) {
    _handler = nullptr;
    _context = nil;
    callbacks = [_callbacks allObjects];
    _engine = nil;
    _queue = nil;
  }
  for (VEKCallback *callback in callbacks) {
    [callback complete:@"session closed" error:YES];
  }
}
@end

@interface VEKRuntime : NSObject <SwiftGeckoViewRuntime>
@property(nonatomic, strong) VEKDispatcher *runtimeDispatcherOwner;
@property(nonatomic, strong) NSMutableDictionary<NSString *, VEKDispatcher *> *named;
@property(nonatomic) VulpraEngineChildProcessHandler childProcessHandler;
@end

@implementation VEKRuntime
- (instancetype)initWithContext:(id)context
                    eventHandler:(VulpraEngineEventHandler)eventHandler
             childProcessHandler:
                 (VulpraEngineChildProcessHandler)childProcessHandler {
  self = [super init];
  if (self) {
    _runtimeDispatcherOwner = [[VEKDispatcher alloc] initWithContext:context
                                                            handler:eventHandler];
    _named = [NSMutableDictionary dictionary];
    _childProcessHandler = childProcessHandler;
  }
  return self;
}
- (void)childProcessDidChangeWithLaunchID:(uint64_t)launchID
                                  childID:(int32_t)childID
                                      pid:(int32_t)pid
                              processType:(NSString *)processType
                                    stage:(GeckoChildProcessStage)stage
             monotonicTimestampNanoseconds:
                 (uint64_t)monotonicTimestampNanoseconds
                              failureCode:
                                  (GeckoChildProcessFailureCode)failureCode
                                   reason:(NSString *)reason {
  VulpraEngineChildProcessHandler handler = _childProcessHandler;
  id context = _runtimeDispatcherOwner.context;
  if (handler && context) {
    handler((__bridge void *)context, launchID, childID, pid,
            (__bridge const void *)[processType copy], (int32_t)stage,
            monotonicTimestampNanoseconds, (int32_t)failureCode,
            reason ? (__bridge const void *)[reason copy] : nullptr);
  }
}
- (id<SwiftEventDispatcher>)runtimeDispatcher { return _runtimeDispatcherOwner; }
- (id<SwiftEventDispatcher>)dispatcherByName:(const char *)name {
  NSString *key = name ? [NSString stringWithUTF8String:name] : @"";
  @synchronized(self) {
    VEKDispatcher *dispatcher = _named[key];
    if (!dispatcher) {
      dispatcher = [[VEKDispatcher alloc]
          initWithContext:_runtimeDispatcherOwner.context
                  handler:_runtimeDispatcherOwner.handler];
      _named[key] = dispatcher;
    }
    return dispatcher;
  }
}
@end

@interface VEKWindow : NSObject
@property(nonatomic, strong) id<GeckoViewWindow> engineWindow;
@property(nonatomic, strong) VEKDispatcher *dispatcher;
@end

@implementation VEKWindow
@end

@interface VEKProcess : NSObject <GeckoProcessExtension>
@end
@implementation VEKProcess
- (void)lockdownSandbox:(NSString *)revision {
  BOOL validRevision = [revision isKindOfClass:NSString.class] && revision.length > 0;
  BOOL extensionHosted =
      [NSBundle.mainBundle.bundleURL.pathExtension isEqualToString:@"appex"] &&
      [NSBundle.mainBundle objectForInfoDictionaryKey:@"NSExtension"] != nil;
  if (!validRevision || !extensionHosted) {
    os_log_fault(OS_LOG_DEFAULT,
                 "Engine sandbox authority mismatch: revision=%{public}@ extension=%{public}d",
                 revision, extensionHosted);
    abort();
  }
  os_log_info(OS_LOG_DEFAULT,
              "Engine sandbox is owned by the ExtensionKit process host, revision=%{public}@",
              revision);
}
@end

@interface NSXPCConnection (VulpraPrivateConnection)
- (xpc_connection_t)_xpcConnection;
@end

void *VEKRuntimeCreate(void *context, VulpraEngineEventHandler eventHandler,
                       VulpraEngineChildProcessHandler childProcessHandler) {
  id owner = context ? (__bridge id)context : nil;
  VEKRuntime *runtime =
      [[VEKRuntime alloc] initWithContext:owner
                            eventHandler:eventHandler
                     childProcessHandler:childProcessHandler];
  return (__bridge_retained void *)runtime;
}

int32_t VEKRuntimeMain(void *runtime, int32_t argc, char **argv) {
  return MainProcessInit(argc, argv, (__bridge VEKRuntime *)runtime);
}

void VEKRuntimeDispatch(void *runtime, const void *type, const void *message) {
  VEKRuntime *owner = (__bridge VEKRuntime *)runtime;
  [owner.runtimeDispatcherOwner send:(__bridge NSString *)type
                             message:(__bridge id)message];
}

void VEKRuntimeDispatchWithCallback(void *runtime, const void *type,
                                    const void *message, void *context,
                                    VulpraEngineCallbackHandler callback) {
  VEKRuntime *owner = (__bridge VEKRuntime *)runtime;
  id<EventCallback> geckoCallback = nil;
  if (callback) {
    geckoCallback = [[VEKGeckoCallback alloc] initWithHandler:callback
                                                      context:context];
  }
  [owner.runtimeDispatcherOwner send:(__bridge NSString *)type
                             message:(__bridge id)message
                            callback:geckoCallback];
}

void *VEKWindowOpen(void *runtime, const void *identifier,
                    const void *initialData, bool privateMode, void *context,
                    VulpraEngineEventHandler handler) {
  (void)runtime;
  id owner = context ? (__bridge id)context : nil;
  VEKDispatcher *dispatcher = [[VEKDispatcher alloc] initWithContext:owner
                                                             handler:handler];
  id<GeckoViewWindow> engineWindow = GeckoViewOpenWindow(
      (__bridge NSString *)identifier, dispatcher,
      (__bridge NSDictionary *)initialData, privateMode);
  if (!engineWindow) return nullptr;
  VEKWindow *window = [VEKWindow new];
  window.engineWindow = engineWindow;
  window.dispatcher = dispatcher;
  return (__bridge_retained void *)window;
}

void *VEKWindowView(void *window) {
  VEKWindow *owner = (__bridge VEKWindow *)window;
  UIView *view = [owner.engineWindow view];
  return (__bridge void *)view;
}

void VEKWindowDispatch(void *window, const void *type, const void *message) {
  VEKWindow *owner = (__bridge VEKWindow *)window;
  [owner.dispatcher send:(__bridge NSString *)type message:(__bridge id)message];
}

void VEKWindowClose(void *window) {
  if (!window) return;
  VEKWindow *owner = (__bridge_transfer VEKWindow *)window;
  [owner.dispatcher invalidate];
  [owner.engineWindow close];
  owner.engineWindow = nil;
}

void VEKCallbackResolve(void *callback, const void *response, bool isError) {
  if (!callback) return;
  VEKCallback *box = (__bridge_transfer VEKCallback *)callback;
  [box complete:response ? (__bridge id)response : NSNull.null error:isError];
}

bool VEKChildProcessStart(void *connection, void *context,
                          VulpraEngineEventHandler handler) {
  NSXPCConnection *owner = (__bridge NSXPCConnection *)connection;
  if (![owner respondsToSelector:@selector(_xpcConnection)]) return false;
  xpc_connection_t xpc = [owner _xpcConnection];
  if (!xpc) return false;
  id contextOwner = context ? (__bridge id)context : nil;
  VEKRuntime *runtime =
      [[VEKRuntime alloc] initWithContext:contextOwner
                            eventHandler:handler
                     childProcessHandler:nullptr];
  VEKProcess *process = [VEKProcess new];
  ChildProcessInit(xpc, process, runtime);
  objc_setAssociatedObject(owner, @selector(_xpcConnection),
                           @[ runtime, process ], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  return true;
}
