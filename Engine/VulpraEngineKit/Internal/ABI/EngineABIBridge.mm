#import "EngineABIBridge.h"

// ─────────────────────────────────────────────────────────────────────────
// PHASE 5 NOTICE: This file is a STUB. All functions return
// VulpraEngineABIUnavailable. The production path bypasses EngineKit entirely
// and talks to the browser engine session (Extensions directory) directly.
//
// This framework target is preserved in the Xcode project so the build graph
// stays stable, but it is NOT wired into the Vulpra app target (the app has
// exactly 3 dependencies: browser framework, Vulpra Helper, OpenIn — see
// test-xcode-graph.py). Do not call these functions expecting real behavior.
//
// When the independent-engine work resumes, replace these stubs with a real
// ABI bridge backed by the precompiled kernel artifact.
// ─────────────────────────────────────────────────────────────────────────

// Phase A deliberately exposes no kernel symbols. The opaque state is owned by
// this translation unit until the verified ABI inventory is available.
static void *vulpraReservedRuntimeState = nullptr;

VulpraEngineABIStatus VulpraEngineRuntimeStart(const char *runtimeRoot,
                                               VulpraEngineRuntimeHandle *runtime) {
    (void)runtimeRoot;
    if (runtime == nullptr) {
        return VulpraEngineABIInvalidArgument;
    }
    *runtime = nullptr;
    vulpraReservedRuntimeState = nullptr;
    return VulpraEngineABIUnavailable;
}

VulpraEngineABIStatus VulpraEngineRuntimeStop(VulpraEngineRuntimeHandle runtime) {
    (void)runtime;
    vulpraReservedRuntimeState = nullptr;
    return VulpraEngineABIUnavailable;
}

VulpraEngineABIStatus VulpraEngineSessionOpen(VulpraEngineRuntimeHandle runtime,
                                              VulpraEngineSessionHandle *session) {
    (void)runtime;
    if (session == nullptr) {
        return VulpraEngineABIInvalidArgument;
    }
    *session = nullptr;
    return VulpraEngineABIUnavailable;
}

VulpraEngineABIStatus VulpraEngineSessionClose(VulpraEngineSessionHandle session) {
    (void)session;
    return VulpraEngineABIUnavailable;
}
