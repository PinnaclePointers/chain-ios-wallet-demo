//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "ChainHelpers.h"
#import "ChainNotification.h"
#import "ChainNotificationResult.h"

// Internal read-write properties.

@interface ChainNotificationResult ()
@property(nonatomic, readwrite) NSInteger droppedCount;
@property(nonatomic, readwrite) NSDictionary* payloadDictionary;
@property(nonatomic, readwrite) NSString* blockchain;
@end



@interface ChainNotificationAddress ()
@property(nonatomic, readwrite) BTCAddress* address;
@property(nonatomic, readwrite) BTCAmount sentAmount;
@property(nonatomic, readwrite) BTCAmount receivedAmount;
@property(nonatomic, readwrite) NSString* transactionHash;
@property(nonatomic, readwrite) NSArray* inputAddresses;
@property(nonatomic, readwrite) NSArray* outputAddresses;
@property(nonatomic, readwrite) NSString* blockHash;
@property(nonatomic, readwrite) NSUInteger confirmations;
@end

@interface ChainNotificationNewTransaction ()
@property(nonatomic, readwrite) BTCTransaction* transaction;
@property(nonatomic, readwrite) NSDictionary* transactionDictionary;
@end

@interface ChainNotificationNewBlock ()
@property(nonatomic, readwrite) BTCBlockHeader* blockHeader;
@property(nonatomic, readwrite) NSDictionary* blockDictionary;
@end

@interface ChainNotificationTransaction ()
@property(nonatomic, readwrite) BTCTransaction* transaction;
@property(nonatomic, readwrite) NSDictionary* transactionDictionary;
@end



@implementation ChainNotificationResult

// Parses the response dictionary and returns an appropriate subclass.
+ (instancetype) notificationResultWithDictionary:(NSDictionary*)dict
{
    NSDictionary* payload = dict[@"payload"];
    NSString* type = payload[@"type"];
    if ([type isEqualToString:ChainNotificationTypeNewTransaction])
    {
        return [[ChainNotificationNewTransaction alloc] initWithDictionary:dict];
    }
    else if ([type isEqualToString:ChainNotificationTypeNewBlock])
    {
        return [[ChainNotificationNewBlock alloc] initWithDictionary:dict];
    }
    else if ([type isEqualToString:ChainNotificationTypeTransaction])
    {
        return [[ChainNotificationTransaction alloc] initWithDictionary:dict];
    }
    else if ([type isEqualToString:ChainNotificationTypeAddress])
    {
        return [[ChainNotificationAddress alloc] initWithDictionary:dict];
    }
    else if ([type isEqualToString:ChainNotificationTypeHeartbeat])
    {
        // Ignore heartbeat messages.
        return nil;
    }
    else
    {
        NSLog(@"ChainNotificationResult: UNKNOWN TYPE RECEIVED: %@ Dictionary: %@", type, dict);
        return nil;
    }
    return nil;
}

// Internal initializer
- (id) initWithDictionary:(NSDictionary*)dict {
    if (self = [super init]) {
        NSDictionary* payload = dict[@"payload"];
        self.payloadDictionary = payload;
        self.droppedCount = [dict[@"dropped"] integerValue];
        self.blockchain = payload[@"block_chain"];
    }
    return self;
}

@end


@implementation ChainNotificationAddress
- (id) initWithDictionary:(NSDictionary*)dict {
    if (self = [super initWithDictionary:dict]) {
        NSDictionary* payload = dict[@"payload"];
        self.address = [BTCAddress addressWithString:payload[@"address"]];
        self.sentAmount = [payload[@"sent"] longLongValue];
        self.receivedAmount = [payload[@"received"] longLongValue];
        self.inputAddresses = [ChainHelpers addressesForAddressStrings:payload[@"input_addresses"]];
        self.outputAddresses = [ChainHelpers addressesForAddressStrings:payload[@"output_addresses"]];
        self.transactionHash = [ChainHelpers filterNSNull:payload[@"transaction_hash"]];
        self.blockHash = [ChainHelpers filterNSNull:payload[@"block_hash"]];
        self.confirmations = [[ChainHelpers filterNSNull:payload[@"confirmations"]] unsignedIntegerValue];
    }
    return self;
}
- (NSString*) type {
    return ChainNotificationTypeAddress;
}
@end


@implementation ChainNotificationTransaction
- (id) initWithDictionary:(NSDictionary*)dict {
    if (self = [super initWithDictionary:dict]) {
        self.transactionDictionary = dict[@"payload"][@"transaction"];
        self.transaction = [ChainHelpers transactionWithDictionary:self.transactionDictionary allowTruncated:NO];
    }
    return self;
}
- (NSString*) type {
    return ChainNotificationTypeTransaction;
}
@end


@implementation ChainNotificationNewTransaction
- (id) initWithDictionary:(NSDictionary*)dict {
    if (self = [super initWithDictionary:dict]) {
        self.transactionDictionary = dict[@"payload"][@"transaction"];
        self.transaction = [ChainHelpers transactionWithDictionary:self.transactionDictionary allowTruncated:NO];
    }
    return self;
}
- (NSString*) type {
    return ChainNotificationTypeNewTransaction;
}
@end


@implementation ChainNotificationNewBlock
- (id) initWithDictionary:(NSDictionary*)dict {
    if (self = [super initWithDictionary:dict]) {
        self.blockDictionary = dict[@"payload"][@"block"];
        self.blockHeader = [ChainHelpers blockHeaderWithDictionary:self.blockDictionary error:NULL];
    }
    return self;
}
- (NSString*) type {
    return ChainNotificationTypeNewBlock;
}
@end
