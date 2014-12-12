//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "Chain.h"
#import "ChainSigner.h"
#import <CoreBitcoin/CoreBitcoin.h>

@interface ChainSigner ()
@property(nonatomic) NSString* blockchain;
@end

@implementation ChainSigner

- (id) initWithBlockchain:(NSString*)blockchain
{
    if (self = [super init])
    {
        _blockchain = blockchain ?: ChainBlockchainMainnet;
    }
    return self;
}

// Keys: {@"1Abc..." => BTCKey}
// Returns template with signatures filled in.
- (NSDictionary*) signTemplate:(NSDictionary*)template keys:(NSDictionary*)keysByAddresses {

    NSMutableDictionary* signedTemplate = [template mutableCopy];
    NSMutableArray* signedInputs = [NSMutableArray array];

    for (NSDictionary* input in template[@"inputs"]) {
        NSMutableDictionary* signedInput = [input mutableCopy];
        if (input[@"signatures"]) {
            NSMutableArray* signedSigSlots = [NSMutableArray array];
            for (NSDictionary* signatureDict in input[@"signatures"])
            {
                BTCKey* key = signatureDict[@"address"] ? keysByAddresses[signatureDict[@"address"]] : nil;

                NSMutableDictionary* sig = [signatureDict mutableCopy];

                 // in case of multisig we sign only what we can.
                if (!key) {
                    [signedSigSlots addObject:sig];
                    continue;
                }

                NSData* hash = BTCDataFromHex(sig[@"hash_to_sign"]);

                NSAssert(hash.length == 32, @"hash_to_sign must be a valid hex-encoded 256-bit hash");

                NSData* ecdsaSig = [key signatureForHash:hash];

                sig[@"public_key"] = BTCHexFromData(key.publicKey);
                sig[@"signature"] = BTCHexFromData(ecdsaSig);

                [signedSigSlots addObject:sig];
            }
            signedInput[@"signatures"] = signedSigSlots;
        }
        [signedInputs addObject:signedInput];
    }
    signedTemplate[@"inputs"] = signedInputs;

    return signedTemplate;
}

// Inputs: [{"private_key": "5v8Q3e5Tvt..." or BTCKey}]
// Returns addresses mapped to keys: {@"1Abc..." => BTCKey}
- (NSDictionary*) extractKeysFromInputs:(NSArray*)inputs {

    NSMutableDictionary* dict = [NSMutableDictionary dictionary];

    NSArray* keys = nil;
    if ([[inputs firstObject] isKindOfClass:[NSDictionary class]]) {
        keys = [inputs valueForKey:@"private_key"];
    } else {
        keys = inputs; // array of BTCKey objects or hex/WIF strings for private keys.
    }

    for (id k in keys) {
        if (k == [NSNull null]) {
            return nil;
        }
        for (BTCKey* key in [self decodeKeys:k]) {
            BTCPublicKeyAddress* address = nil;
            if ([_blockchain isEqualToString:ChainBlockchainTestnet]) {
                address = [BTCPublicKeyAddressTestnet addressWithData:BTCHash160(key.publicKey)];
            } else {
                address = [BTCPublicKeyAddress addressWithData:BTCHash160(key.publicKey)];
            }
            NSParameterAssert(address);

            dict[address.base58String] = key;
        }
    }

    return dict;
}

// Returns one or two possible keys for a given object.
- (NSArray*) decodeKeys:(id)k {
    if ([k isKindOfClass:[BTCKey class]]) {
        return @[ k ];
    }

    // if k is not BTCKey, it must be either a hex string or WIF-encoded key.
    NSParameterAssert([k isKindOfClass:[NSString class]]);

    // Try WIF encoding. If it returns nil, it must be hex.
    BTCKey* key = [[BTCKey alloc] initWithWIF:k];

    if (key) {
        return @[ key ];
    }

    // If it's not WIF, it must be hex-encoded private key.
    // We cannot know if public key must be compressed or not, so we'll return
    // both keys: with compressed and uncompressed pubkeys.
    NSData* privkey = BTCDataFromHex(k);

    NSParameterAssert(privkey);

    BTCKey* k1 = [[BTCKey alloc] initWithPrivateKey:privkey];
    k1.publicKeyCompressed = YES;

    NSParameterAssert(k1);

    BTCKey* k2 = [[BTCKey alloc] initWithPrivateKey:privkey];
    k2.publicKeyCompressed = NO;

    NSParameterAssert(k2);

    return @[ k1, k2 ];
}

@end
