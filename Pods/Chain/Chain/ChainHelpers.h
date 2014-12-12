//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BTCAddress;
@class BTCTransaction;
@class BTCTransactionOutput;
@class BTCTransactionInput;
@class BTCBlock;
@class BTCBlockHeader;

@interface ChainHelpers : NSObject

+ (NSString*) addressStringForAddress:(id)addr;

+ (NSArray*) addressStringsForAddresses:(NSArray*)addrs;

+ (NSArray*) addressesForAddressStrings:(NSArray*)addressStrings;

+ (BTCTransaction*) transactionWithDictionary:(NSDictionary*)dict;

+ (BTCTransaction*) transactionWithDictionary:(NSDictionary*)dict allowTruncated:(BOOL)allowTruncated;

+ (BTCTransactionInput*) transactionInputWithDictionary:(NSDictionary*)inputDict;

+ (BTCTransactionOutput*) transactionOutputWithDictionary:(NSDictionary*)outputDict;

+ (NSArray*) opreturnsWithDictionaries:(NSArray*) dicts error:(NSError**)errorOut;

+ (NSString*) blockIDForBlockArgument:(id)block;

+ (BTCBlockHeader*) blockHeaderWithDictionary:(NSDictionary*)dict error:(NSError**)errorOut;

// Returns nil if obj is NSNull.
+ (id) filterNSNull:(id)obj;

@end
