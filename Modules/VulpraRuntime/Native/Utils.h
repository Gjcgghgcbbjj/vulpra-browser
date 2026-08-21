//
//  Utils.h
//  Reynard
//
//  Created by Minh Ton on 12/4/26.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

BOOL getEntitlementValue(NSString *key);
void updateJetsamControl(pid_t pid);

/// Per-content-process ceiling: bounded well below the main-process limit so a
/// single runaway tab cannot starve the whole system (aggregate overcommit was
/// unmanaged when every process took the main-process share).
void updateJetsamControlForChild(pid_t pid);

int spawnRoot(NSString *path, NSArray<NSString *> *args);

NS_ASSUME_NONNULL_END
