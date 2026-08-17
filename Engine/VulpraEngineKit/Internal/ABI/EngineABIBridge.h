#ifndef VULPRA_ENGINE_ABI_BRIDGE_H
#define VULPRA_ENGINE_ABI_BRIDGE_H

#include <stdint.h>

typedef struct VulpraEngineRuntimeOpaque *VulpraEngineRuntimeHandle;
typedef struct VulpraEngineSessionOpaque *VulpraEngineSessionHandle;

typedef enum VulpraEngineABIStatus {
    VulpraEngineABIUnavailable = 0,
    VulpraEngineABIOK = 1,
    VulpraEngineABIInvalidArgument = 2,
    VulpraEngineABIFailed = 3,
} VulpraEngineABIStatus;

VulpraEngineABIStatus VulpraEngineRuntimeStart(const char *runtimeRoot,
                                               VulpraEngineRuntimeHandle *runtime);
VulpraEngineABIStatus VulpraEngineRuntimeStop(VulpraEngineRuntimeHandle runtime);
VulpraEngineABIStatus VulpraEngineSessionOpen(VulpraEngineRuntimeHandle runtime,
                                              VulpraEngineSessionHandle *session);
VulpraEngineABIStatus VulpraEngineSessionClose(VulpraEngineSessionHandle session);

#endif
