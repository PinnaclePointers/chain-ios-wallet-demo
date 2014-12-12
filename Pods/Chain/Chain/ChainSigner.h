//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ChainSigner : NSObject

- (id) initWithBlockchain:(NSString*)blockchain;

// Keys: {@"1Abc..." => BTCKey}
// Returns template with signatures filled in.
- (NSDictionary*) signTemplate:(NSDictionary*)template keys:(NSDictionary*)keysByAddresses;

// Inputs: [{"private_key": "5v8Q3e5Tvt..."}]
// Returns addresses mapped to keys: {@"1Abc..." => @"5v8Q3e5Tvt..."}
- (NSDictionary*) extractKeysFromInputs:(NSArray*)inputs;

@end
