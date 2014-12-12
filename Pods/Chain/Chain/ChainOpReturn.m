//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "ChainOpReturn.h"
#import "ChainLog.h"
#import <CoreBitcoin/CoreBitcoin.h>

@interface ChainOpReturn ()
@property(nonatomic, readwrite) NSData* transactionHash;
@property(nonatomic, readwrite) NSString* transactionID;
@property(nonatomic, readwrite) NSData* data;
@property(nonatomic, readwrite) NSString* text;
@property(nonatomic, readwrite) NSArray* senderAddresses;
@property(nonatomic, readwrite) NSArray* receiverAddresses;
@property(nonatomic, readwrite) NSDictionary* dictionary;
@end

@implementation ChainOpReturn

- (id) initWithDictionary:(NSDictionary*) dictionary
{
    if (self = [super init])
    {
        self.dictionary = dictionary;
        self.transactionID = [self ensure:dictionary[@"transaction_hash"] isKindOf:[NSString class]];
        self.transactionHash = BTCHashFromID(self.transactionID);

        if (!self.transactionHash) {
            ChainError(@"OP_RETURN dictionary contains invalid or missing transaction_hash.");
            return nil;
        }

        self.data = BTCDataFromHex([self ensure:dictionary[@"hex"] isKindOf:[NSString class]]);

        if (!self.data) {
            ChainError(@"OP_RETURN dictionary contains invalid or missing hex data.");
            return nil;
        }

        // This is currently broken: [self ensure:dictionary[@"text"] isKindOf:[NSString class]];
        self.text = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];

        {
            NSMutableArray* addrs = [NSMutableArray array];
            for (NSString* string in [self ensure:dictionary[@"sender_addresses"] isKindOf:[NSArray class]]) {
                BTCAddress* addr = [BTCAddress addressWithString:[self ensure:string isKindOf:[NSString class]]];
                if (addr) {
                    [addrs addObject:addr];
                } else {
                    ChainError(@"OP_RETURN dictionary contains invalid address in sender_addresses: %@", string);
                    return nil;
                }
            }
            self.senderAddresses = addrs;
        }

        {
            NSMutableArray* addrs = [NSMutableArray array];
            for (NSString* string in [self ensure:dictionary[@"receiver_addresses"] isKindOf:[NSArray class]]) {
                BTCAddress* addr = [BTCAddress addressWithString:[self ensure:string isKindOf:[NSString class]]];
                if (addr) {
                    [addrs addObject:addr];
                } else {
                    ChainError(@"OP_RETURN dictionary contains invalid address in receiver_addresses: %@", string);
                    return nil;
                }
            }
            self.receiverAddresses = addrs;
        }
    }
    return self;
}

- (id) filterNSNull:(id)obj {
    if (obj == [NSNull null]) return nil;
    return obj;
}

- (id) ensure:(id)obj isKindOf:(id)cls {
    id obj2 = [self filterNSNull:obj];
    if (obj2 == nil) return nil;
    if ([obj2 isKindOfClass:cls]) return obj2;
    return nil;
}

@end
