//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBitcoin/CoreBitcoin.h>

#import "ChainAddressInfo.h"
#import "ChainOpReturn.h"
#import "ChainNotification.h"
#import "ChainNotificationResult.h"
#import "ChainNotificationObserver.h"

extern NSString* const ChainErrorDomain;

extern NSString* const ChainBlockchainMainnet;
extern NSString* const ChainBlockchainTestnet;

extern NSString* const ChainAPIVersion2;
extern NSString* const ChainAPIVersion1;

@class BTCAddress;
@class BTCTransaction;

@interface Chain : NSObject

// Bitcoin blockchain being used.
// Use ChainBlockchainMainnet or ChainBlockchainTestnet.
// Default is mainnet.
@property(nonatomic) NSString *blockchain;

// API version to be used.
// Default is v2.
@property(nonatomic) NSString *version;

// Access shared Chain instance and specify the token.
// Call this method before calling `+sharedInstance`.
+ (instancetype) sharedInstanceWithToken:(NSString *)token;

// Use this method to access shared Chain instance this after specifying the token with `+sharedInstanceWithToken:`.
+ (instancetype) sharedInstance;

// Creates Chain instance with a given token.
- (id) initWithToken:(NSString *)token;


#pragma mark - Address

// Returns ChainAddressInfo instance for a given address (NSString or BTCAddress type).
- (void) getAddress:(id)address completionHandler:(void (^)(ChainAddressInfo *addressInfo, NSError *error))completionHandler;

// Returns an array of ChainAddressInfo instances for an array of addresses (NSString or BTCAddress types).
- (void) getAddresses:(NSArray *)addresses completionHandler:(void (^)(NSArray *addressInfos, NSError *error))completionHandler;


#pragma mark - Transactions By Address

// Returns an array of transactions (BTCTransaction objects) for a given address or an array of addresses.
// Each address instance could be an NSString or BTCAddress.
// Optional `limit` parameter specifies the maximum amount of transactions to be returned (0 meaning not limit).
// Each transaction has the following informational properties set:
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
- (void) getAddressTransactions:(id)address completionHandler:(void (^)(NSArray *transactions, NSError *error))completionHandler;
- (void) getAddressesTransactions:(NSArray *)addresses completionHandler:(void (^)(NSArray *transactions, NSError *error))completionHandler;
- (void) getAddressTransactions:(id)address limit:(NSInteger)limit completionHandler:(void (^)(NSArray *transactions, NSError *error))completionHandler;
- (void) getAddressesTransactions:(NSArray *)addresses limit:(NSInteger)limit completionHandler:(void (^)(NSArray *transactions, NSError *error))completionHandler;


#pragma mark - Unspent Outputs By Address


// Returns an array of unspent outputs (BTCTransactionOutput instances) for a given address or an array of addresses.
// Each address instance could be an NSString or BTCAddress.
// Each output instance has the following informational properties set:
// - index: Int (index in its transaction)
// - confirmations: Int
// - spent: Bool
// - userInfo["addresses"]: [BTCAddress] (addresses used in each input)
- (void)getAddressUnspents:(id)address completionHandler:(void (^)(NSArray *unspentOutputs, NSError *error))completionHandler;
- (void)getAddressesUnspents:(NSArray *)addresses completionHandler:(void (^)(NSArray *unspentOutputs, NSError *error))completionHandler;


#pragma mark - OP_RETURN


// Returns an array of ChainOpReturn instances for a given address (NSString or BTCAddress).
- (void)getAddressOpReturns:(id)address completionHandler:(void (^)(NSArray *opreturns, NSError *error))completionHandler;

// Returns a single ChainOpReturn instance for a given transaction.
// If this transaction has not OP_RETURN outputs, returns nil (error equals nil too).
// Transaction can be specified using one of the following types:
// - NSString (transaction ID; reversed hash in hex)
// - NSData (transaction Hash)
// - BTCTransaction
- (void)getTransactionOpReturn:(id)tx completionHandler:(void (^)(ChainOpReturn *opreturn, NSError *error))completionHandler;

// Same as above, but returns an array of ChainOpReturn instances.
// Currently supports only one instance, but may return more in the future.
- (void)getTransactionOpReturns:(id)tx completionHandler:(void (^)(NSArray *opreturns, NSError *error))completionHandler;

// Returns an array of ChainOpReturn instances for a given block.
// Block can be specified using one of the following types:
// - NSString (block ID; reversed hash in hex)
// - NSNumber (block height)
// - NSData (block hash)
// - BTCBlockHeader
// - BTCBlock
- (void)getBlockOpReturns:(id)block completionHandler:(void (^)(NSArray *opreturns, NSError *error))completionHandler;

// Returns an array of ChainOpReturn instances for a block with a given ID or binary hash.
- (void)getBlockOpReturnsByHash:(id)blockHash completionHandler:(void (^)(NSArray *opreturns, NSError *error))completionHandler;

// Returns an array of ChainOpReturn instances for a block with a given height.
- (void)getBlockOpReturnsByHeight:(NSInteger)height completionHandler:(void (^)(NSArray *opreturns, NSError *error))completionHandler;

// Returns an array of ChainOpReturn instances for the latest known block.
- (void)getLatestBlockOpReturns:(void (^)(NSArray *opreturns, NSError *error))completionHandler;


#pragma mark - Transaction


// Loads complete transaction using transaction hash (NSData) or transaction ID (NSString):
- (void)getTransaction:(id)txhash completionHandler:(void (^)(BTCTransaction *transaction, NSError *error))completionHandler;

// Sends transaction represented as one of the following:
// - BTCTransaction
// - NSData (raw binary)
// - NSString (raw binary in hex)
// - NSDictionary (signed tx template)
// Returns a fully signed transaction that was broadcasted.
- (void)sendTransaction:(id)tx completionHandler:(void (^)(BTCTransaction* tx, NSError *error))completionHandler;


#pragma mark - Transaction Builder


// Builds, signs and sends transaction in one call.
// Response is the same as from `-sendTransaction:completionHandler:` call.
// params[@"inputs"] should contain @{@"address": <base58-encoded address>,
//                                    @"private_key": <hex|WIF|BTCKey>}
// params[@"outputs"] should contain @{@"address": <base58-encoded address>,
//                                     @"amount": @(satoshis)}
- (void) transact:(NSDictionary*)params completionHandler:(void (^)(BTCTransaction *tx, NSError *error))completionHandler;

// Makes a request to build a transaction with given parameters.
- (void) buildTransaction:(NSDictionary*)params completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler;

// Signs transaction template received from `-buildTransaction:completionHandler:`
// with the given keys and sends the result to Chain to complete transaction.
- (NSDictionary*) signTransactionTemplate:(NSDictionary*)template keys:(NSArray* /* {"private_key": <BTCKey> or <WIF NSString> } */)keys;



#pragma mark - Blocks


// Returns BTCBlockHeader instance with a list of transaction IDs (userInfo["transactionIDs"])
// Block can be identified by either:
// - NSNumber (height)
// - NSString (block ID, reversed block hash in hex)
// - NSData (block hash)
// - BTCBlockHeader
// - BTCBlock
- (void) getBlockHeader:(id)block completionHandler:(void (^)(BTCBlockHeader *blockHeader, NSError *error))completionHandler;
- (void) getBlockHeaderByHeight:(NSInteger)height completionHandler:(void (^)(BTCBlockHeader *blockHeader, NSError *error))completionHandler;
- (void) getLatestBlockHeader:(void (^)(BTCBlockHeader *blockHeader, NSError *error))completionHandler;

// Returns a complete block with all transactions.
// Block can be identified by either:
// - NSNumber (height)
// - NSString (block ID, reversed block hash in hex)
// - NSData (block hash)
// - BTCBlockHeader
// - BTCBlock
- (void) getBlock:(id)block completionHandler:(void (^)(BTCBlock *block, NSError *error))completionHandler;
- (void) getLatestBlock:(void (^)(BTCBlock *block, NSError *error))completionHandler;



#pragma mark - Notifications


// Returns an observer that connects to Chain and begins receiving events.
// Call 'disconnect' on observer instance to stop receiving notifications.
- (ChainNotificationObserver*) observerForNotification:(ChainNotification*)notification;
- (ChainNotificationObserver*) observerForNotification:(ChainNotification*)notification resultHandler:(void(^)(ChainNotificationResult*))resultHandler;
- (ChainNotificationObserver*) observerForNotifications:(NSArray*)notifications;
- (ChainNotificationObserver*) observerForNotifications:(NSArray*)notifications resultHandler:(void(^)(ChainNotificationResult*))resultHandler;


@end
