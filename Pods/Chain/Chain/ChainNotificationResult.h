//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBitcoin/CoreBitcoin.h>

@class BTCTransaction;
@class BTCBlockHeader;

// Base class for each kind of notification result.
// You will always receive a concrete subclass depending on type of notification.
@interface ChainNotificationResult : NSObject

// One of ChainNotificationType* values.
@property(nonatomic, readonly) NSString* type;

// The number of Results dropped by Chain since the last Result was delivered.
// This may occur over slow network connections.
@property(nonatomic, readonly) NSInteger droppedCount;

// Raw dictionary containing payload with specific type.
// Depending on the type you will receive a specific subclass of ChainNotificationResult with
// all relevant properties set, so you normally do not need to access this dictionary.
@property(nonatomic, readonly) NSDictionary* payloadDictionary;

// Either ChainBlockchainMainnet or ChainBlockchainTestnet
@property(nonatomic, readonly) NSString* blockchain;

// Parses the response dictionary and returns an appropriate subclass.
+ (instancetype) notificationResultWithDictionary:(NSDictionary*)dict;

@end




// Concrete subclasses of ChainNotificationResult class.
// =====================================================




@interface ChainNotificationAddress : ChainNotificationResult

// An address for which notification is received.
@property(nonatomic, readonly) BTCAddress* address;

// The total amount sent by the address in the new transaction.
// This does not include change sent back to the address.
@property(nonatomic, readonly) BTCAmount sentAmount;

// The total amount (in satoshis) received by the address in the new transaction.
// This does not include change received back to the address.
@property(nonatomic, readonly) BTCAmount receivedAmount;

// Reversed transaction hash in hex (aka "transaction ID").
@property(nonatomic, readonly) NSString* transactionHash;

// Array of BTCAddress instances that send funds in the transaction.
@property(nonatomic, readonly) NSArray* inputAddresses;

// Array of BTCAddress instances that receive funds in the transaction.
@property(nonatomic, readonly) NSArray* outputAddresses;

// Reversed block hash in hex (aka "block ID") for the block containing transaction.
// If transaction is not confirmed yet, contains nil.
@property(nonatomic, readonly) NSString* blockHash;

// The number of confirmations on the new transaction.
@property(nonatomic, readonly) NSUInteger confirmations;

@end


@interface ChainNotificationNewTransaction : ChainNotificationResult

// BTCTransaction instance that has been detected on the network.
// The transaction has the following informational properties set:
// - blockID: String
// - blockHash: NSData
// - blockHeight: Int
// - blockDate: NSDate
// - confirmations: Int
// - fee: BTCAmount
// - inputs.userInfo["addresses"]: [BTCAddress] (addresses used in each input)
// - inputs.value: BTCAmount (amount spent by the input)
// - outputs.userInfo["addresses"]: [BTCAddress] (addresses used in each output)
// - userInfo["chain_received_at"]: NSDate
@property(nonatomic, readonly) BTCTransaction* transaction;

// Transaction details as returned from the server.
@property(nonatomic, readonly) NSDictionary* transactionDictionary;

@end


@interface ChainNotificationNewBlock : ChainNotificationResult

// Returns BTCBlockHeader instance with a list of transaction IDs (userInfo["transactionIDs"])
@property(nonatomic, readonly) BTCBlockHeader* blockHeader;

// Block details as returned from the server.
@property(nonatomic, readonly) NSDictionary* blockDictionary;

@end


@interface ChainNotificationTransaction : ChainNotificationResult

// BTCTransaction instance that has been detected on the network.
// The transaction has the following informational properties set:
// - blockID: String
// - blockHash: NSData
// - blockHeight: Int
// - blockDate: NSDate
// - confirmations: Int
// - fee: BTCAmount
// - inputs.userInfo["addresses"]: [BTCAddress] (addresses used in each input)
// - inputs.value: BTCAmount (amount spent by the input)
// - outputs.userInfo["addresses"]: [BTCAddress] (addresses used in each output)
// - userInfo["chain_received_at"]: NSDate
@property(nonatomic, readonly) BTCTransaction* transaction;

// Transaction details
@property(nonatomic, readonly) NSDictionary* transactionDictionary;
@end

