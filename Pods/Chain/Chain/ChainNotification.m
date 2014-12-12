//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "Chain.h"
#import "ChainNotification.h"

NSString* const ChainNotificationTypeAddress = @"address";
NSString* const ChainNotificationTypeTransaction = @"transaction";
NSString* const ChainNotificationTypeNewTransaction = @"new-transaction";
NSString* const ChainNotificationTypeNewBlock = @"new-block";
NSString* const ChainNotificationTypeHeartbeat = @"heartbeat"; // can be received from time to time

@interface ChainNotification ()
@property(nonatomic, readwrite) NSString* type;
@end

@implementation ChainNotification

// Instantiates a notification with a given type.
- (id) initWithType:(NSString*)type
{
    if (self = [super init])
    {
        self.type = type;
        self.blockchain = ChainBlockchainMainnet;
    }
    return self;
}

// Instantiates a notification with type "transaction" watching for transaction
// with a given hash.
- (id) initWithTransactionHash:(NSString*)txhash
{
    NSParameterAssert(txhash);
    if (self = [self initWithType:ChainNotificationTypeTransaction])
    {
        self.transactionHash = txhash;
    }
    return self;
}

// Instantiates a notification with type "address" watching for a given address.
- (id) initWithAddress:(id)address
{
    NSParameterAssert(address);

    if ([address isKindOfClass:[NSString class]]) {
        address = [BTCAddress addressWithString:address];
        if (!address) return nil;
    }

    if (![address isKindOfClass:[BTCAddress class]]) {
        [NSException raise:@"ChainException" format:@"Invalid address class (%@), expected NSString or BTCAddress.", [address class]];
    }

    if (self = [self initWithType:ChainNotificationTypeAddress])
    {
        self.address = address;
    }
    return self;
}


- (NSDictionary*) dictionary
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];

    dict[@"type"] = self.type;
    dict[@"block_chain"] = self.blockchain ?: ChainBlockchainMainnet;
    if (self.transactionHash) dict[@"transaction_hash"] = self.transactionHash;
    if (self.address) dict[@"address"] = self.address.string;

    return dict;
}

@end
