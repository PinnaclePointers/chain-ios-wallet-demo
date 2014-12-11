//
//  CNSecretStore.h
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BTCKey;
@class BTCAddress;
@interface CNSecretStore : NSObject

// Shared Chain-specific secret store.
+ (instancetype) chainSecretStore;

// Name of the service under which all secret items are stored.
@property(nonatomic, readonly) NSString* serviceName;

// The most recent error after reading/writing the secret.
// E.g. if passcode is not set, then you will get an error trying to save the secret key.
@property(nonatomic, readonly) NSError* error;

// This property stores secret info.
// Access to it is possible only within the `-unlock:reason:` block.
// Additional items (seed, BTCKeychain, BTCMnemonic) could be added in a similar way.
@property(nonatomic) BTCKey* key;

// This property stores less sensistive info that is unlocked when device is unlocked.
// You can access it without calling `-unlock:reason:` in order to, for instance,
// display an address balance to the user.
@property(nonatomic, readonly) BTCKey* publicKey;

// Current address used to receive funds (computed from publicKey).
@property(nonatomic, readonly) BTCAddress* currentAddress;

// Creates an instance with a given service name shared by all items.
- (id) initWithServiceName:(NSString*)serviceName;

// Enables access to items with a given human-readable reason.
// Runs on caller's thread.
- (void) unlock:(void(^)(CNSecretStore* store))block reason:(NSString*)reason;

// Enables access to items with a given human-readable reason.
// Runs on private background thread and returns back to main thread using completion block.
// Caller may pass the result and error from unlock block to completion block.
- (void) unlock:(id(^)(CNSecretStore* store, NSError** errorOut))block reason:(NSString*)reason completionBlock:(void(^)(id result, NSError* error)) completionBlock;
- (void) unlock:(id(^)(CNSecretStore* store, NSError** errorOut))block reason:(NSString*)reason completionBlock:(void(^)(id result, NSError* error)) completionBlock queue:(dispatch_queue_t)queue;

@end
