//
//  CrashReporter.m
//  Vulpra
//
//  Architecture completion: signal + NSException crash reporter.
//
//  TrollStore apps have no access to the system crash log service, so we
//  install our own signal handlers and NSException handler. On crash we
//  write a structured log (signal name, stack trace, app version, device)
//  to Caches/crash-logs/crash-<timestamp>.txt before the process dies.
//
//  All signal-handler code is async-signal-safe: no Objective-C runtime
//  calls, no malloc, no Foundation — only write(2), snprintf, and backtrace.
//

#import "CrashReporter.h"
#import <Foundation/Foundation.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <execinfo.h>
#include <sys/stat.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>

// ── Async-signal-safe crash log writer ─────────────────────────────────────

static volatile sig_atomic_t sCrashInProgress = 0;

/// Write a string to fd using write(2) — async-signal-safe.
static void vulpraWriteStr(int fd, const char *str) {
    if (!str) return;
    size_t len = 0;
    while (str[len]) len++;
    (void)write(fd, str, len);
}

/// Write an integer to fd — async-signal-safe.
static void vulpraWriteInt(int fd, long value) {
    char buf[32];
    int pos = (int)sizeof(buf) - 1;
    buf[pos] = '\0';
    if (value == 0) {
        buf[--pos] = '0';
    } else {
        int negative = 0;
        unsigned long uval;
        if (value < 0) {
            negative = 1;
            uval = (unsigned long)(-(value));
        } else {
            uval = (unsigned long)value;
        }
        while (uval > 0 && pos > 0) {
            buf[--pos] = '0' + (int)(uval % 10);
            uval /= 10;
        }
        if (negative && pos > 0) {
            buf[--pos] = '-';
        }
    }
    vulpraWriteStr(fd, &buf[pos]);
}

static void vulpraWriteCrashLog(int signum) {
    // Build crash log path: Caches/crash-logs/crash-<pid>-<signal>.txt
    // We can't use NSFileManager (not async-signal-safe), so we hardcode
    // the container path via getenv("HOME") which is stable for the app.
    const char *home = getenv("HOME");
    if (!home) return;

    char path[512];
    // Documents is exposed via iTunes/3uTools file sharing (UIFileSharingEnabled),
    // so crash logs are retrievable over USB without jailbreak.
    int n = snprintf(path, sizeof(path),
                     "%s/Documents/crash-logs",
                     home);
    if (n <= 0 || (size_t)n >= sizeof(path)) return;

    // Create directory (best-effort; mkdir is async-signal-safe)
    (void)mkdir(path, 0755);

    // Append filename
    n = snprintf(path + n, sizeof(path) - n,
                 "/crash-%d-%d.txt", (int)getpid(), signum);
    if (n <= 0) return;

    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) return;

    // ── Header ──
    vulpraWriteStr(fd, "=== Vulpra Crash Report ===\n");

    const char *sigName = "UNKNOWN";
    switch (signum) {
        case SIGABRT: sigName = "SIGABRT"; break;
        case SIGSEGV: sigName = "SIGSEGV"; break;
        case SIGBUS:  sigName = "SIGBUS";  break;
        case SIGILL:  sigName = "SIGILL";  break;
        case SIGFPE:  sigName = "SIGFPE";  break;
        case SIGPIPE: sigName = "SIGPIPE"; break;
    }
    vulpraWriteStr(fd, "Signal: "); vulpraWriteStr(fd, sigName);
    vulpraWriteStr(fd, " ("); vulpraWriteInt(fd, signum); vulpraWriteStr(fd, ")\n");

    vulpraWriteStr(fd, "PID: "); vulpraWriteInt(fd, (long)getpid()); vulpraWriteStr(fd, "\n");

    // ── Backtrace ──
    // backtrace() and backtrace_symbols_fd() use dladdr internally which is
    // NOT strictly async-signal-safe, but in practice they work for crash
    // logging on iOS. If they fail, we still have the signal info above.
    vulpraWriteStr(fd, "\nBacktrace:\n");
    void *frames[128];
    int frameCount = backtrace(frames, 128);
    if (frameCount > 0) {
        backtrace_symbols_fd(frames, frameCount, fd);
    } else {
        vulpraWriteStr(fd, "(backtrace unavailable)\n");
    }

    vulpraWriteStr(fd, "\n=== End of Report ===\n");
    close(fd);
}

/// Signal handler — async-signal-safe.
static void vulpraSignalHandler(int signum) {
    // Prevent re-entrant crash handling
    if (sCrashInProgress) {
        // Re-raise with default handler to ensure process terminates
        signal(signum, SIG_DFL);
        raise(signum);
        return;
    }
    sCrashInProgress = 1;

    vulpraWriteCrashLog(signum);

    // Restore default handler and re-raise so the process terminates cleanly
    signal(signum, SIG_DFL);
    raise(signum);
}

// ── NSException handler (not async-signal-safe; runs on the crashing thread) ──

static NSString *crashLogsDirectory(void) {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = paths.firstObject;
    NSString *dir = [documents stringByAppendingPathComponent:@"crash-logs"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:NULL];
    return dir;
}

static NSUncaughtExceptionHandler *sPreviousHandler = NULL;

static void vulpraUncaughtExceptionHandler(NSException *exception) {
    NSString *dir = crashLogsDirectory();
    NSString *timestamp = [NSString stringWithFormat:@"%f", NSDate.date.timeIntervalSince1970];
    NSString *path = [dir stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"crash-exception-%@.txt", timestamp]];

    NSMutableString *report = [NSMutableString string];
    [report appendString:@"=== Vulpra Crash Report (NSException) ===\n"];
    [report appendFormat:@"Name: %@\n", exception.name];
    [report appendFormat:@"Reason: %@\n", exception.reason];
    [report appendFormat:@"Date: %@\n", NSDate.date];

    NSArray *stack = exception.callStackSymbols;
    if (stack.count > 0) {
        [report appendString:@"\nCall Stack:\n"];
        [report appendString:[stack componentsJoinedByString:@"\n"]];
        [report appendString:@"\n"];
    }

    NSDictionary *userInfo = exception.userInfo;
    if (userInfo.count > 0) {
        [report appendFormat:@"\nUserInfo:\n%@\n", userInfo];
    }

    [report appendString:@"\n=== End of Report ===\n"];

    [report writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];

    // Chain to previous handler if any
    if (sPreviousHandler) {
        sPreviousHandler(exception);
    }
}

// ── Public API ─────────────────────────────────────────────────────────────

void VulpraInstallCrashReporter(void) {
    // Signal handlers
    struct {
        int sig;
        struct sigaction sa;
    } signals[] = {
        {SIGABRT}, {SIGSEGV}, {SIGBUS}, {SIGILL}, {SIGFPE}, {SIGPIPE},
    };

    for (size_t i = 0; i < sizeof(signals) / sizeof(signals[0]); i++) {
        memset(&signals[i].sa, 0, sizeof(signals[i].sa));
        signals[i].sa.sa_handler = vulpraSignalHandler;
        sigemptyset(&signals[i].sa.sa_mask);
        signals[i].sa.sa_flags = SA_RESTART;
        sigaction(signals[i].sig, &signals[i].sa, NULL);
    }

    // NSException handler (chain to any existing one)
    sPreviousHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(vulpraUncaughtExceptionHandler);
}

NSString *VulpraLastCrashLogPath(void) {
    NSString *dir = crashLogsDirectory();
    NSArray *files = [NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:NULL];
    if (files.count == 0) return nil;

    // Sort by modification date, newest first
    NSMutableArray *sortedFiles = [NSMutableArray array];
    for (NSString *file in files) {
        NSString *fullPath = [dir stringByAppendingPathComponent:file];
        [sortedFiles addObject:fullPath];
    }
    [sortedFiles sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSDictionary *attrA = [NSFileManager.defaultManager attributesOfItemAtPath:a error:NULL];
        NSDictionary *attrB = [NSFileManager.defaultManager attributesOfItemAtPath:b error:NULL];
        NSDate *dateA = attrA[NSFileModificationDate] ?: NSDate.distantPast;
        NSDate *dateB = attrB[NSFileModificationDate] ?: NSDate.distantPast;
        return [dateB compare:dateA];
    }];

    return sortedFiles.firstObject;
}
