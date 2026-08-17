//
//  CrashReporter.h
//  Vulpra
//
//  Architecture completion: signal + NSException crash reporter.
//  TrollStore apps cannot use the system crash log service, so we capture
//  crashes ourselves and write a structured log to Caches/crash-logs/.
//

#ifndef CrashReporter_h
#define CrashReporter_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Install signal handlers (SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGPIPE)
/// and an NSUncaughtExceptionHandler. On crash, a structured log is written to
/// Caches/crash-logs/crash-<timestamp>.txt before the process terminates.
///
/// Must be called once at the very start of main(), before any other code runs.
void VulpraInstallCrashReporter(void);

/// Returns the path to the most recent crash log, or nil if none exists.
/// Used by the UI to offer "report last crash" on next launch.
NSString * _Nullable VulpraLastCrashLogPath(void);

NS_ASSUME_NONNULL_END

#endif /* CrashReporter_h */
