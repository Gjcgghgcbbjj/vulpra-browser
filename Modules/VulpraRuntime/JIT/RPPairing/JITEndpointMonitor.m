//
//  JITEndpointMonitor.m
//  Reynard
//
//  Endpoint connectivity monitoring extracted for Vulpra.
//

#import "JITSupport.h"
#import "JITErrors.h"

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/tcp.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>

static dispatch_source_t endpointMonitorTimer = nil;
static NSUInteger endpointMonitorCursor = 0;
static BOOL endpointFailureLatched = NO;

static dispatch_queue_t endpointMonitorQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.vulpra.browser.jit.support.endpoint-monitor", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

// MARK: Endpoint Connectivity Monitoring

static NSMutableDictionary<NSNumber *, NSDictionary<NSString *, id> *> *monitoredEndpointsByPID(void) {
    static NSMutableDictionary<NSNumber *, NSDictionary<NSString *, id> *> *endpoints;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        endpoints = [NSMutableDictionary dictionary];
    });
    return endpoints;
}

static NSMutableDictionary<NSString *, NSNumber *> *endpointFailureCounts(void) {
    static NSMutableDictionary<NSString *, NSNumber *> *failureCounts;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        failureCounts = [NSMutableDictionary dictionary];
    });
    return failureCounts;
}

static void stopEndpointMonitorLocked(void) {
    if (!endpointMonitorTimer) return;
    dispatch_source_cancel(endpointMonitorTimer);
    endpointMonitorTimer = nil;
}

static BOOL probeTCPEndpoint(NSString *targetAddress, uint16_t port, NSTimeInterval timeoutSeconds, int *errorCodeOut) {
    if (errorCodeOut) *errorCodeOut = 0;

    int socketFD = socket(AF_INET, SOCK_STREAM, 0);
    if (socketFD < 0) {
        if (errorCodeOut) *errorCodeOut = errno;
        return NO;
    }

    int noSigPipe = 1;
    setsockopt(socketFD, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, sizeof(noSigPipe));

    int noDelay = 1;
    setsockopt(socketFD, IPPROTO_TCP, TCP_NODELAY, &noDelay, sizeof(noDelay));

    int flags = fcntl(socketFD, F_GETFL, 0);
    if (flags < 0 || fcntl(socketFD, F_SETFL, flags | O_NONBLOCK) < 0) {
        close(socketFD);
        if (errorCodeOut) *errorCodeOut = errno;
        return NO;
    }

    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_port = htons(port);

    if (inet_pton(AF_INET, targetAddress.UTF8String, &address.sin_addr) != 1) {
        close(socketFD);
        if (errorCodeOut) *errorCodeOut = EINVAL;
        return NO;
    }

    int connectResult = connect(socketFD, (const struct sockaddr *)&address, sizeof(address));
    if (connectResult == 0) {
        close(socketFD);
        return YES;
    }

    if (errno != EINPROGRESS) {
        if (errorCodeOut) *errorCodeOut = errno;
        close(socketFD);
        return NO;
    }

    struct timeval timeoutValue;
    timeoutValue.tv_sec = (time_t)timeoutSeconds;
    timeoutValue.tv_usec = (suseconds_t)((timeoutSeconds - timeoutValue.tv_sec) * 1000000.0);

    fd_set writeSet;
    FD_ZERO(&writeSet);
    FD_SET(socketFD, &writeSet);

    int selectResult = select(socketFD + 1, NULL, &writeSet, NULL, &timeoutValue);
    if (selectResult <= 0) {
        if (errorCodeOut) *errorCodeOut = (selectResult == 0 ? ETIMEDOUT : errno);
        close(socketFD);
        return NO;
    }

    int socketError = 0;
    socklen_t socketErrorLength = sizeof(socketError);
    if (getsockopt(socketFD, SOL_SOCKET, SO_ERROR, &socketError, &socketErrorLength) != 0) {
        if (errorCodeOut) *errorCodeOut = errno;
        close(socketFD);
        return NO;
    }

    close(socketFD);

    if (socketError != 0 && errorCodeOut) *errorCodeOut = socketError;
    return socketError == 0;
}

static NSDictionary<NSString *, id> *endpointEntryForKey(NSString *endpointKey, NSNumber **pidOut) {
    __block NSDictionary<NSString *, id> *matchedEntry = nil;
    __block NSNumber *matchedPID = nil;

    [monitoredEndpointsByPID()
     enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull pid, NSDictionary<NSString *, id> * _Nonnull entry, BOOL * _Nonnull stop) {
        NSString *candidateKey = entry[@"key"];
        if (![candidateKey isEqualToString:endpointKey]) return;
        matchedEntry = entry;
        matchedPID = pid;
        *stop = YES;
    }];

    if (pidOut) *pidOut = matchedPID;
    return matchedEntry;
}

static void postEndpointConnectivityFailure(NSNumber *pid, NSString *targetAddress, NSNumber *portNumber, NSError *error) {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:4];
    if (pid) userInfo[@"pid"] = pid;
    if (targetAddress) userInfo[@"address"] = targetAddress;
    if (portNumber) userInfo[@"port"] = portNumber;
    if (error) userInfo[@"error"] = error;

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"com.vulpra.browser.jit.endpoint-monitor-failed" object:nil userInfo:userInfo];
    });
}

static void performEndpointMonitorTick(void) {
    NSDictionary<NSNumber *, NSDictionary<NSString *, id> *> *entriesByPID = monitoredEndpointsByPID();
    if (entriesByPID.count == 0) {
        [endpointFailureCounts() removeAllObjects];
        endpointMonitorCursor = 0;
        stopEndpointMonitorLocked();
        return;
    }

    NSMutableOrderedSet<NSString *> *uniqueEndpointKeys = [NSMutableOrderedSet orderedSet];
    for (NSDictionary<NSString *, id> *entry in entriesByPID.allValues) {
        NSString *endpointKey = entry[@"key"];
        if (endpointKey.length > 0) [uniqueEndpointKeys addObject:endpointKey];
    }

    if (uniqueEndpointKeys.count == 0) return;
    if (endpointMonitorCursor >= uniqueEndpointKeys.count) endpointMonitorCursor = 0;

    NSString *endpointKey = uniqueEndpointKeys[endpointMonitorCursor];
    endpointMonitorCursor = (endpointMonitorCursor + 1) % uniqueEndpointKeys.count;

    NSNumber *samplePID = nil;
    NSDictionary<NSString *, id> *endpointEntry = endpointEntryForKey(endpointKey, &samplePID);
    NSString *targetAddress = endpointEntry[@"address"];
    NSNumber *portNumber = endpointEntry[@"port"];

    if (targetAddress.length == 0 || !portNumber) return;

    uint16_t port = (uint16_t)portNumber.unsignedShortValue;
    BOOL endpointHealthy = probeTCPEndpoint(targetAddress, port, 0.35, NULL);

    if (endpointHealthy) {
        [endpointFailureCounts() removeObjectForKey:endpointKey];
        return;
    }

    NSMutableDictionary<NSString *, NSNumber *> *failureCounts = endpointFailureCounts();
    NSUInteger failureCount = [failureCounts[endpointKey] unsignedIntegerValue] + 1;
    failureCounts[endpointKey] = @(failureCount);

    if (failureCount < 2) return;

    endpointFailureLatched = YES;
    stopEndpointMonitorLocked();

    NSError *connectivityError = MakeError(EndpointConnectivityLost);
    postEndpointConnectivityFailure(samplePID, targetAddress, portNumber, connectivityError);
}

static void startEndpointMonitorLocked(void) {
    if (endpointMonitorTimer || endpointFailureLatched) return;

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, endpointMonitorQueue());
    if (!timer) return;

    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), (uint64_t)NSEC_PER_SEC, NSEC_PER_MSEC * 100);
    dispatch_source_set_event_handler(timer, ^{
        performEndpointMonitorTick();
    });

    endpointMonitorTimer = timer;
    dispatch_resume(timer);
}

void registerJITEndpointForPID(int32_t pid, NSString *targetAddress, uint16_t port) {
    if (pid <= 0 || targetAddress.length == 0 || port == 0) return;

    dispatch_async(endpointMonitorQueue(), ^{
        NSString *endpointKey = [NSString stringWithFormat:@"%@:%u", targetAddress, port];
        monitoredEndpointsByPID()[@(pid)] = @{
            @"key": endpointKey,
            @"address": [targetAddress copy],
            @"port": @(port),
        };

        [endpointFailureCounts() removeObjectForKey:endpointKey];
        startEndpointMonitorLocked();
    });
}

void unregisterJITEndpointForPID(int32_t pid) {
    if (pid <= 0) return;

    dispatch_async(endpointMonitorQueue(), ^{
        [monitoredEndpointsByPID() removeObjectForKey:@(pid)];

        if (monitoredEndpointsByPID().count == 0) {
            [endpointFailureCounts() removeAllObjects];
            endpointMonitorCursor = 0;
            stopEndpointMonitorLocked();
        }
    });
}

void resetJITEndpointMonitor(void) {
    dispatch_sync(endpointMonitorQueue(), ^{
        [monitoredEndpointsByPID() removeAllObjects];
        [endpointFailureCounts() removeAllObjects];
        endpointMonitorCursor = 0;
        endpointFailureLatched = NO;
        stopEndpointMonitorLocked();
    });
}
