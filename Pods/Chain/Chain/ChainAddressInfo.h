//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBitcoin/CoreBitcoin.h>

@interface ChainAddressInfo : NSObject

// A concrete BTCAddress subclass instace described by the properties that follow.
@property(nonatomic, readonly) BTCAddress* address;

// The total balance of the address in satoshis (total = confirmed + unconfirmed).
@property(nonatomic, readonly) BTCAmount totalBalance;

// The total amount in satoshis that the address has ever received.
@property(nonatomic, readonly) BTCAmount totalReceived;

// The total amount in satoshis that the address has ever sent.
@property(nonatomic, readonly) BTCAmount totalSent;

// The confirmed balance of the address in satoshis (excluding unconfirmed transactions).
@property(nonatomic, readonly) BTCAmount confirmedBalance;

// The confirmed amount in satoshis that the address has ever received.
@property(nonatomic, readonly) BTCAmount confirmedReceived;

// The confirmed amount in satoshis that the address has ever sent.
@property(nonatomic, readonly) BTCAmount confirmedSent;

// Dictionary representation of the address info.
@property(nonatomic, readonly) NSDictionary* dictionary;

- (id) initWithDictionary:(NSDictionary*) dictionary;

@end
