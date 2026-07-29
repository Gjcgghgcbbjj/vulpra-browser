#import <Foundation/Foundation.h>
#include <stdint.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*VulpraEngineEventHandler)(void *_Nullable context,
                                         const void *type,
                                         const void *_Nullable message,
                                         void *_Nullable callback);
typedef void (*VulpraEngineChildProcessHandler)(
    void *_Nullable context, uint64_t launchID, int32_t childID, int32_t pid,
    const void *processType, int32_t stage,
    uint64_t monotonicTimestampNanoseconds, int32_t failureCode,
    const void *_Nullable reason);

// Type and message values are borrowed for the duration of the handler call.
// Callback values are owned handoffs and must be consumed exactly once by
// VEKCallbackResolve, including cancellation paths.

void *_Nullable VEKRuntimeCreate(void *_Nullable context,
                                 VulpraEngineEventHandler eventHandler,
                                 VulpraEngineChildProcessHandler _Nullable
                                     childProcessHandler);
int32_t VEKRuntimeMain(void *runtime, int32_t argc,
                       char *_Nullable *_Nonnull argv);
void VEKRuntimeDispatch(void *runtime, const void *type,
                        const void *_Nullable message);

void *_Nullable VEKWindowOpen(void *runtime, const void *identifier,
                              const void *initialData, bool privateMode,
                              void *_Nullable context,
                              VulpraEngineEventHandler handler);
void *_Nullable VEKWindowView(void *window);
void VEKWindowDispatch(void *window, const void *type,
                       const void *_Nullable message);
void VEKWindowClose(void *window);

void VEKCallbackResolve(void *callback, const void *_Nullable response,
                        bool isError);
bool VEKChildProcessStart(void *connection, void *_Nullable context,
                          VulpraEngineEventHandler handler);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
