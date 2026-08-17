// Simulator-only stub for Gecko symbols that exist only in patched Gecko
// builds. The pre-compiled simulator runtime does not include Vulpra's
// Gecko patches, so we provide no-op stubs to satisfy the linker.
#include <TargetConditionals.h>
#if TARGET_OS_SIMULATOR

#include <stdint.h>

// Stub: ReportJITStatusForChild — in real Gecko builds this is exported
// from IOSBootstrap.mm via the JIT patch. The simulator runtime lacks it.
// Signature must match the Swift declaration in RuntimeJITCoordinator.
__attribute__((used))
void ReportJITStatusForChild(int32_t pid, _Bool enabled, void *info) {
    // No-op in simulator: JIT is always available via the host process.
    (void)pid; (void)enabled; (void)info;
}

#endif
