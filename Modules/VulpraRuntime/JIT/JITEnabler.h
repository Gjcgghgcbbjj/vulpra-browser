//
//  JITEnabler.h
//  Reynard
//
//  Created by Minh Ton on 11/3/26.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface JITEnabler : NSObject

@property(class, nonatomic, readonly) JITEnabler *shared;

- (BOOL)enableJITForPID:(int32_t)pid
          hasTXMSupport:(BOOL)hasTXMSupport
                  error:(NSError *_Nullable *_Nullable)error

NS_SWIFT_NAME(enableJIT(forPID:hasTXMSupport:));

/// Best-effort warm-up of the DDI pairing provider: creates the device provider
/// (reads `pairingFile.plist`) and mounts the Developer Disk Image ahead of the
/// first content-process attach, so attach does not consume the child's
/// five-second JIT readiness window on first use.
- (BOOL)preflightJITProviderWithError:(NSError *_Nullable *_Nullable)error
    NS_SWIFT_NAME(preflightJITProvider());

- (void)detachAllJITSessions NS_SWIFT_NAME(detachAllJITSessions());

@end

NS_ASSUME_NONNULL_END
