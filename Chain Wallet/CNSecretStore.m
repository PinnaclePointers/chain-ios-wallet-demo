//
//  CNSecretStore.m
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "CNSecretStore.h"
#import <CoreBitcoin/CoreBitcoin.h>

@interface CNSecretStore ()
@property(nonatomic, readwrite) NSString* serviceName;
@property(nonatomic, readwrite) NSError* error;
@property(nonatomic) NSString* unlockReason;
@end

@implementation CNSecretStore

+ (instancetype) chainSecretStore {
    static CNSecretStore* store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[self alloc] initWithServiceName:@"ChainWalletV1"];
    });
    return store;
}


- (id) initWithServiceName:(NSString*)serviceName {
    NSParameterAssert(serviceName);
    if (!serviceName) return nil;
    if (self = [super init]) {
        self.serviceName = serviceName;
    }
    return self;
}

- (void) unlock:(void(^)(CNSecretStore*))block reason:(NSString*)reason {
    NSParameterAssert(block);
    NSParameterAssert(reason);

    id prevError = self.error;
    id prevReason = self.unlockReason;

    self.unlockReason = reason;
    self.error = nil;

    block(self);

    self.unlockReason = prevReason;
    self.error = prevError;
}

- (void) unlock:(id(^)(CNSecretStore* store, NSError** errorOut))block reason:(NSString*)reason completionBlock:(void(^)(id result, NSError* error))completionBlock {
    [self unlock:block reason:reason completionBlock:completionBlock queue:dispatch_get_main_queue()];
}

- (void) unlock:(id(^)(CNSecretStore* store, NSError** errorOut))block reason:(NSString*)reason completionBlock:(void(^)(id result, NSError* error))completionBlock queue:(dispatch_queue_t)queue {

    NSParameterAssert(block);
    NSParameterAssert(reason);
    NSParameterAssert(completionBlock);
    NSParameterAssert(queue);

    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        __block id result = nil;
        __block NSError* error = nil;
        [self unlock:^(CNSecretStore *store) {
            result = block(store, &error);
        } reason:reason];

        dispatch_async(queue, ^{
            completionBlock(result, error);
        });
    });
}


#pragma mark - Secrets


- (BTCKey*) key {
    if (!self.unlockReason) {
        [NSException raise:@"CNSecretStore Exception" format:@"You must unlock the secret store before reading the key."];
    }
    NSError* error = nil;
    NSData* wifData = [self readItemWithName:@"wif" error:&error];
    if (!wifData) {
        self.error = error;
        return nil;
    }
    NSString* wif = [[NSString alloc] initWithData:wifData encoding:NSUTF8StringEncoding];
    BTCPrivateKeyAddress* addr = (BTCPrivateKeyAddress*)[BTCAddress addressWithBase58String:wif];
    return addr.key;
}

- (void) setKey:(BTCKey *)key {
    if (!self.unlockReason) {
        [NSException raise:@"CNSecretStore Exception" format:@"You must unlock the secret store before writing the key."];
    }
    NSString* wif = key.privateKeyAddress.base58String;
    NSError* error = nil;
    if (![self writeItem:[wif dataUsingEncoding:NSUTF8StringEncoding] withName:@"wif" accessibility: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly error:&error]) {
        self.error = error;
        return;
    }
    NSData* pubkey = key.publicKey;
    if (![self writeItem:pubkey withName:@"pubkey" accessibility:kSecAttrAccessibleWhenUnlockedThisDeviceOnly error:&error]) {
        self.error = error;
    }
}

- (BTCKey*) publicKey {
    NSError* error = nil;
    NSData* pubkey = [self readItemWithName:@"pubkey" error:&error];
    if (!pubkey) {
        self.error = error;
        return nil;
    }
    BTCKey* key = [[BTCKey alloc] initWithPublicKey:pubkey];
    return key;
}

- (BTCAddress*) currentAddress {
    return self.publicKey.publicKeyAddress;
}


#pragma mark - Secret Accessors


- (NSData*) readItemWithName:(NSString*)name error:(NSError**)errorOut {

    CFDictionaryRef value = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)[self keychainSearchRequestForItemNamed:name],
                                          (CFTypeRef *)&value);
    if (status == errSecSuccess) {
        return ( __bridge_transfer NSData *)value;
    }
    else if (status == errSecItemNotFound) {
        // We have no data stored there yet, so we don't return an error.
        return nil;
    }

    if (errorOut) *errorOut = [self errorForOSStatus:status];

    return nil;
}

- (BOOL) writeItem:(NSData*)data withName:(NSString*)name accessibility:(CFTypeRef)accessibility error:(NSError**)errorOut {

    NSParameterAssert(name);
    NSParameterAssert(accessibility);

    // We cannot update the value, only attributes of the keychain items.
    // So to update value we delete the item and add a new one.
    OSStatus status1 = SecItemDelete((__bridge CFDictionaryRef)[self keychainSearchRequestForItemNamed:name]);

    if (status1 != errSecSuccess && status1 != errSecItemNotFound) {
        if (errorOut) *errorOut = [self errorForOSStatus:status1];
        return NO;
    }

    if (!data) {
        return YES;
    }

    NSDictionary* createRequest = [self keychainCreateRequestForItemNamed:name data:data accessibility:accessibility];
    CFDictionaryRef attributes = NULL;
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)createRequest, (CFTypeRef *)&attributes);
    if (status != errSecSuccess) {
        if (errorOut) *errorOut = [self errorForOSStatus:status];
        return NO;
    }
    return YES;
}



#pragma mark - Apple Keychain Helpers


- (NSMutableDictionary*) keychainBaseDictForItemNamed:(NSString*)name {

    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    dict[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;

    // IMPORTANT: need to save password with both keys: service + account. kSecAttrGeneric as used in Apple's code does not guarantee uniqueness.
    // http://useyourloaf.com/blog/2010/04/28/keychain-duplicate-item-when-adding-password.html
    // http://stackoverflow.com/questions/4891562/ios-keychain-services-only-specific-values-allowed-for-ksecattrgeneric-key
    dict[(__bridge id)kSecAttrService] = self.serviceName;
    dict[(__bridge id)kSecAttrAccount] = name;

    return dict;
}

- (NSMutableDictionary*) keychainSearchRequestForItemNamed:(NSString*)name {

    NSMutableDictionary* dict = [self keychainBaseDictForItemNamed:name];
    if (self.unlockReason) dict[(__bridge id)kSecUseOperationPrompt] = self.unlockReason;
    dict[(__bridge id)kSecReturnData] = @YES;

    return dict;
}

- (NSMutableDictionary*) keychainCreateRequestForItemNamed:(NSString*)name data:(NSData*)data accessibility:(CFTypeRef)accessibility  {

    NSMutableDictionary* dict = [self keychainBaseDictForItemNamed:name];

    if (data) dict[(__bridge id)kSecValueData] = data;

#if TARGET_IPHONE_SIMULATOR
    // Simulator does not support touch id or passcode, but we need to test the UI on simulator,
    // so lets assume it's implicitly unlocked.
    if (accessibility == kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly) {
        accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    }
#endif

    // Need to set access control object to require user enter passcode / touch id every time.
    // For all other accessibility modes we can read items any time device is unlocked.
    if (accessibility == kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly) {
        SecAccessControlRef sac = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, kSecAccessControlUserPresence, NULL);
        NSAssert(sac, @"");
        if (sac) {
            dict[(__bridge id)kSecAttrAccessControl] = (__bridge_transfer id)sac;
            dict[(__bridge id)kSecUseNoAuthenticationUI] = @YES; // cargo cult.
        } else {
            NSLog(@"CANNOT CREATE SecAccessControlRef");
        }
    } else {
        // For all other
        dict[(__bridge id)kSecAttrAccessible] = (__bridge id)accessibility;
    }
    return dict;
}



// OSStatus values specific to Security framework.
//enum
//{
//    errSecSuccess                               = 0,       /* No error. */
//    errSecUnimplemented                         = -4,      /* Function or operation not implemented. */
//    errSecIO                                    = -36,     /*I/O error (bummers)*/
//    errSecOpWr                                  = -49,     /*file already open with with write permission*/
//    errSecParam                                 = -50,     /* One or more parameters passed to a function where not valid. */
//    errSecAllocate                              = -108,    /* Failed to allocate memory. */
//    errSecUserCanceled                          = -128,    /* User canceled the operation. */
//    errSecBadReq                                = -909,    /* Bad parameter or invalid state for operation. */
//    errSecInternalComponent                     = -2070,
//    errSecNotAvailable                          = -25291,  /* No keychain is available. You may need to restart your computer. */
//    errSecDuplicateItem                         = -25299,  /* The specified item already exists in the keychain. */
//    errSecItemNotFound                          = -25300,  /* The specified item could not be found in the keychain. */
//    errSecInteractionNotAllowed                 = -25308,  /* User interaction is not allowed. */
//    errSecDecode                                = -26275,  /* Unable to decode the provided data. */
//    errSecAuthFailed                            = -25293,  /* The user name or passphrase you entered is not correct. */
//};


- (NSError*) errorForOSStatus:(OSStatus)statusCode {
    NSString* description = nil;
    NSString* codeName = nil;

    switch (statusCode) {
    case errSecSuccess:
        codeName = @"errSecSuccess";
        description = @"No error.";
        break;
    case errSecUnimplemented:
        codeName = @"errSecUnimplemented";
        description = @"Function or operation not implemented.";
        break;
    case errSecIO:
        codeName = @"errSecIO";
        description = @"I/O error (bummers)";
        break;
    case errSecParam:
        codeName = @"errSecParam";
        description = @"One or more parameters passed to a function where not valid.";
        break;
    case errSecAllocate:
        codeName = @"errSecAllocate";
        description = @"Failed to allocate memory.";
        break;
    case errSecUserCanceled:
        codeName = @"errSecUserCanceled";
        description = @"User canceled the operation.";
        break;
    case errSecBadReq:
        codeName = @"errSecBadReq";
        description = @"Bad parameter or invalid state for operation.";
        break;
    case errSecInternalComponent:
        codeName = @"errSecInternalComponent";
        description = @"";
        break;
    case errSecNotAvailable:
        codeName = @"errSecNotAvailable";
        description = @"No keychain is not available. You may need to restart your computer.";
        break;
    case errSecDuplicateItem:
        codeName = @"errSecDuplicateItem";
        description = @"That password already exists in the keychain.";
        break;
    case errSecItemNotFound:
        codeName = @"errSecItemNotFound";
        description = @"The item could not be found in the keychain.";
        break;
    case errSecInteractionNotAllowed:
        codeName = @"errSecInteractionNotAllowed";
        description = @"User interaction is not allowed.";
        break;
    case errSecDecode:
        codeName = @"errSecDecode";
        description = @"Unable to decode the provided data.";
        break;
    case errSecAuthFailed:
        codeName = @"errSecAuthFailed";
        description = @"The username or password you entered is not correct.";
        break;
    case -34018:
        codeName = @"-34018";
        description = @"Shared Keychain entitlements might be incorrect. Cf. http://stackoverflow.com/questions/20344255/secitemadd-and-secitemcopymatching-returns-error-code-34018-errsecmissingentit";
        break;
    default:
        codeName = @(statusCode).stringValue;
        description = @"Other keychain error.";
        break;
    }

    return [NSError errorWithDomain:@"com.Chain"
                               code:statusCode
                           userInfo:@{NSLocalizedDescriptionKey:
                                    [NSString stringWithFormat:@"%@ (%@)",
                                     description, codeName]}];
}

@end
