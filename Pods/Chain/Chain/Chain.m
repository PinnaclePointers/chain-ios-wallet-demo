//
//  Chain.m
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "Chain.h"
#import "ChainConnection.h"
#import "ChainSigner.h"
#import "ChainHelpers.h"
#import <CoreBitcoin/CoreBitcoin.h>
#import <ISO8601DateFormatter.h>

NSString* const ChainErrorDomain = @"com.chain.error";

NSString* const ChainBlockchainMainnet = @"bitcoin";
NSString* const ChainBlockchainTestnet = @"testnet3";

NSString* const ChainAPIVersion2 = @"v2";
NSString* const ChainAPIVersion1 = @"v1";

NSString* const ChainDefaultHostname = @"api.chain.com";
NSString* const ChainDefaultWebSocketHostname = @"ws.chain.com";

@interface Chain()
@property(nonatomic) NSString *token;
@property(nonatomic) ChainConnection *connection;
@end

@implementation Chain

static Chain *sharedInstance = nil;

+ (instancetype)sharedInstanceWithToken:(NSString *)token {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Chain alloc] initWithToken:token];
    });
    return sharedInstance;
}

+ (instancetype)sharedInstance {
    if (sharedInstance == nil) {
        [NSException raise:@"ChainException" format:@"Called +sharedInstance before specifying token with +sharedInstanceWithToken:"];
    }
    return sharedInstance;
}

- (id)initWithToken:(NSString *)token {
    if (self = [super init]) {

        self.connection = [[ChainConnection alloc] init];
        self.connection.hostname = ChainDefaultHostname;
        self.connection.webSocketHostname = ChainDefaultWebSocketHostname;
        self.token = token;
        self.blockchain = ChainBlockchainMainnet;
        self.version = ChainAPIVersion2;
    }
    return self;
}

- (void) setToken:(NSString *)token {
    _token = token;
    self.connection.token = _token;
}

- (void) setBlockchain:(NSString *)blockchain
{
    _blockchain = blockchain;
    self.connection.blockchain = blockchain;
}

- (void) setVersion:(NSString *)version
{
    _version = version;
    self.connection.version = version;
}


#pragma mark - Address


- (void)getAddress:(id)address completionHandler:(void (^)(ChainAddressInfo *addressInfo, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(address != nil);
    [self getAddresses:@[ address ] completionHandler:^(NSArray *addressInfos, NSError *error) {
        if (addressInfos) {
            completionHandler(addressInfos.firstObject, nil);
        } else {
            completionHandler(nil, error);
        }
    }];
}

- (void)getAddresses:(NSArray *)addresses completionHandler:(void (^)(NSArray *addressInfos, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(addresses != nil);

    NSString* addr = [[ChainHelpers addressStringsForAddresses:addresses] componentsJoinedByString:@","];
    NSString *pathString = [NSString stringWithFormat:@"addresses/%@", addr];
    NSURL *url = [self.connection URLWithPath:pathString];
    [self.connection startGetTaskWithURL:url completionHandler:^(NSDictionary *dictionary, NSError *error) {

        if (!dictionary) {
            completionHandler(nil, error);
            return;
        }

        NSMutableArray* results = [NSMutableArray array];

        for (NSDictionary* dict in dictionary[@"results"] ?: @[dictionary]) {
            ChainAddressInfo* addrInfo = [[ChainAddressInfo alloc] initWithDictionary:dict];
            if (addrInfo) [results addObject:addrInfo];
        }
        completionHandler(results, nil);
    }];
}



#pragma mark - Transactions By Address


- (void) getAddressTransactions:(id)address completionHandler:(void (^)(NSArray *transactions, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(address != nil);
    [self getAddressesTransactions:@[address] limit:0 completionHandler:completionHandler];
}

- (void) getAddressesTransactions:(NSArray *)addresses completionHandler:(void (^)(NSArray *transactions, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(addresses != nil);
    [self getAddressesTransactions:addresses limit:0 completionHandler:completionHandler];
}

- (void)getAddressTransactions:(id)address limit:(NSInteger)limit completionHandler:(void (^)(NSArray *transactions, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(address != nil);
    [self getAddressesTransactions:@[address] limit:0 completionHandler:completionHandler];
}

- (void)getAddressesTransactions:(NSArray *)addresses limit:(NSInteger)limit completionHandler:(void (^)(NSArray *transactions, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(addresses != nil);

    NSString* addrs = [[ChainHelpers addressStringsForAddresses:addresses] componentsJoinedByString:@","];
    NSString *pathString = [NSString stringWithFormat:@"addresses/%@/transactions", addrs];
    if (limit > 0) {
        pathString = [pathString stringByAppendingString:[NSString stringWithFormat:@"?limit=%@", @(limit)]];
    }

    NSURL *url = [self.connection URLWithPath:pathString];
    [self.connection startGetTaskWithURL:url completionHandler:^(NSDictionary *dictionary, NSError *error) {
        if (!dictionary) {
            completionHandler(nil, error);
            return;
        }

        NSMutableArray* results = [NSMutableArray array];

        // This will be our semaphore for async calls.
        // There will be no racing conditions since all callbacks land on main queue.
        __block int loadingTxsCount = 0;

        for (NSDictionary* txdict in dictionary[@"results"]) {
            BTCTransaction* tx = [ChainHelpers transactionWithDictionary:txdict allowTruncated:YES];
            if (tx) {
                [results addObject:tx];
            } else {

                // Tx has probably truncated number of inputs and outputs.
                // Lets fetch it with getTransaction API.
                // Note: these calls will run in parallel, but will finish on main thread (in random order).

                // Remember position using a placeholder object.
                [results addObject:[NSNull null]];
                NSUInteger txindex = results.count - 1;

                loadingTxsCount++;
                NSLog(@"Chain: transaction is truncated, loading full data separately: %@ [#%@]", txdict[@"hash"], @(loadingTxsCount));
                [self getTransaction:txdict[@"hash"] completionHandler:^(BTCTransaction *fullTx, NSError *error) {

                    if (loadingTxsCount == 0) return; // all calls were cancelled.

                    loadingTxsCount--;

                    if (!fullTx) {
                        loadingTxsCount = 0;
                        completionHandler(nil, error);
                        return;
                    }

                    results[txindex] = fullTx;

                    if (loadingTxsCount == 0) {
                        completionHandler(results, nil);
                    }
                }];
            }
        }

        // If all transactions are already here, return immediately.
        if (loadingTxsCount == 0) {
            completionHandler(results, nil);
        }
    }];
}



#pragma mark - Unspent Outputs By Address



- (void)getAddressUnspents:(id)address completionHandler:(void (^)(NSArray *unspentOutputs, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(address != nil);

    [self getAddressesUnspents:@[address] completionHandler:completionHandler];
}

- (void)getAddressesUnspents:(NSArray *)addresses completionHandler:(void (^)(NSArray *unspentOutputs, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(addresses != nil);

    NSString *addrs = [[ChainHelpers addressStringsForAddresses:addresses] componentsJoinedByString:@","];
    NSString *pathString = [NSString stringWithFormat:@"addresses/%@/unspents", addrs];
    NSURL *url = [self.connection URLWithPath:pathString];
    [self.connection startGetTaskWithURL:url completionHandler:^(NSDictionary *dictionary, NSError *error) {

        if (!dictionary) {
            completionHandler(nil, error);
            return;
        }

        NSMutableArray* results = [NSMutableArray array];
        for (NSDictionary* txoutdict in dictionary[@"results"]) {
            BTCTransactionOutput* txout = [ChainHelpers transactionOutputWithDictionary:txoutdict];
            [results addObject:txout];
        }

        completionHandler(results, nil);
    }];
}



#pragma mark - OP_RETURN


// Returns an array of ChainOpReturn instances for a given address (NSString or BTCAddress).
- (void)getAddressOpReturns:(id)address completionHandler:(void (^)(NSArray *opreturns, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(address != nil);

    if ([address isKindOfClass:[BTCAddress class]]) {
        address = [(BTCAddress*)address base58String];
    }

    NSString *pathString = [NSString stringWithFormat:@"addresses/%@/op-returns", address];
    NSURL *url = [self.connection URLWithPath:pathString];
    [self.connection startGetTaskWithURL:url completionHandler:^(NSDictionary *dictionary, NSError *error) {
        if (!dictionary) {
            completionHandler(nil, error);
            return;
        }
        NSArray* opreturns = [ChainHelpers opreturnsWithDictionaries:dictionary[@"results"] error:&error];
        completionHandler(opreturns, opreturns ? nil : error);
    }];
}

// Retrusn a single ChainOpReturn instance for a given transaction.
// Transaction can be specified using one of the following types:
// - NSString (transaction ID; reversed hash in hex)
// - NSData (transaction Hash)
// - BTCTransaction
- (void)getTransactionOpReturn:(id)tx completionHandler:(void (^)(ChainOpReturn *opreturn, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(tx != nil);

    [self getTransactionOpReturns:tx completionHandler:^(NSArray *opreturns, NSError *error) {
        completionHandler(opreturns.firstObject, error);
    }];
}

// Same as above, but returns an array of ChainOpReturn instances.
// Currently supports only one instance, but may return more in the future.
- (void)getTransactionOpReturns:(id)tx completionHandler:(void (^)(NSArray *opreturns, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(tx != nil);

    NSString* txid = nil;

    if ([tx isKindOfClass:[NSString class]]) {
        txid = tx;
    } else if ([tx isKindOfClass:[NSData class]]) {
        txid = BTCIDFromHash(tx);
    } else if ([tx isKindOfClass:[BTCTransaction class]]) {
        txid = [(BTCTransaction*)tx transactionID];
    } else {
        [NSException raise:@"ChainException" format:@"Unexpected type for transaction identifier: %@", [tx class]];
    }

    // When backend API supports multiple op-returns per transaction,
    // we will update this method to take advantage of it.
    NSString *pathString = [NSString stringWithFormat:@"transactions/%@/op-return", txid];
    NSURL *url = [self.connection URLWithPath:pathString];
    [self.connection startGetTaskWithURL:url completionHandler:^(NSDictionary *dictionary, NSError *error) {
        if (!dictionary) {
            completionHandler(nil, error);
            return;
        }
        NSArray* opreturns = [ChainHelpers opreturnsWithDictionaries:@[dictionary] error:&error];
        completionHandler(opreturns, opreturns ? nil : error);
    }];
}

// Returns an array of ChainOpReturn instances for a given block.
// Block can be specified using one of the following types:
// - NSString (block ID; reversed hash in hex)
// - NSData (block hash)
// - BTCBlockHeader
// - BTCBlock
- (void)getBlockOpReturns:(id)block completionHandler:(void (^)(NSArray *opreturns, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(block != nil);

    NSString* blockid = [ChainHelpers blockIDForBlockArgument:block];

    NSString *pathString = [NSString stringWithFormat:@"blocks/%@/op-returns", blockid];
    NSURL *url = [self.connection URLWithPath:pathString];
    [self.connection startGetTaskWithURL:url completionHandler:^(NSDictionary *dictionary, NSError *error) {
        if (!dictionary) {
            completionHandler(nil, error);
            return;
        }
        NSArray* opreturns = [ChainHelpers opreturnsWithDictionaries:dictionary[@"results"] error:&error];
        completionHandler(opreturns, opreturns ? nil : error);
    }];
}

- (void)getBlockOpReturnsByHash:(id)blockhash completionHandler:(void (^)(NSArray *opreturns, NSError *error))completionHandler  {
    [self getBlockOpReturns:blockhash completionHandler:completionHandler];
}

// Returns an array of ChainOpReturn instances for a block with a given height.
- (void)getBlockOpReturnsByHeight:(NSInteger)height completionHandler:(void (^)(NSArray *opreturns, NSError *error))completionHandler {
    [self getBlockOpReturns:@(height) completionHandler:completionHandler];
}

// Returns an array of ChainOpReturn instances for the latest known block.
- (void)getLatestBlockOpReturns:(void (^)(NSArray *opreturns, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);

    NSString *pathString = [NSString stringWithFormat:@"blocks/latest/op-returns"];
    NSURL *url = [self.connection URLWithPath:pathString];
    [self.connection startGetTaskWithURL:url completionHandler:^(NSDictionary *dictionary, NSError *error) {
        if (!dictionary) {
            completionHandler(nil, error);
            return;
        }
        NSArray* opreturns = [ChainHelpers opreturnsWithDictionaries:dictionary[@"results"] error:&error];
        completionHandler(opreturns, opreturns ? nil : error);
    }];
}



#pragma mark - Transaction


- (void)getTransaction:(id)txhash completionHandler:(void (^)(BTCTransaction *transaction, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(txhash != nil);
    NSParameterAssert([txhash isKindOfClass:[NSString class]] || [txhash isKindOfClass:[NSData class]]);

    if ([txhash isKindOfClass:[NSData class]]) {
        txhash = BTCIDFromHash(txhash);
    }

    NSString *pathString = [NSString stringWithFormat:@"transactions/%@", txhash];
    NSURL *url = [self.connection URLWithPath:pathString];
    [self.connection startGetTaskWithURL:url completionHandler:^(NSDictionary *dictionary, NSError *error) {
        if (!dictionary) {
            completionHandler(nil, error);
            return;
        }
        BTCTransaction* tx = [ChainHelpers transactionWithDictionary:dictionary];
        NSAssert(tx, @"Should parse transaction correctly");
        completionHandler(tx, nil);
    }];
}


- (void)sendTransaction:(id)tx completionHandler:(void (^)(BTCTransaction* tx, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);

    NSString *pathString = [NSString stringWithFormat:@"transactions/send"];
    NSURL *url = [self.connection URLWithPath:pathString];

    NSDictionary *requestDictionary = nil;

    if ([tx isKindOfClass:[BTCTransaction class]]) {
        tx = ((BTCTransaction*)tx).data;
    }

    if ([tx isKindOfClass:[NSData class]]) {
        tx = BTCHexFromData(tx);
    }

    if ([tx isKindOfClass:[NSString class]]) {
        requestDictionary = @{@"signed_hex": tx};
    } else if ([tx isKindOfClass:[NSDictionary class]]) {
        requestDictionary = tx;
    } else {
        [NSException raise:@"ChainException" format:@"Unexpected type of transaction argument: %@", [tx class]];
    }

    [self.connection startPostTaskWithURL:url dictionary:requestDictionary completionHandler:^(NSDictionary *dictionary, NSError *error) {

        if (!dictionary) {
            completionHandler(nil, error);
            return;
        }
        NSData* txhash = BTCHashFromID(dictionary[@"transaction_hash"]);
        NSData* txdata = BTCDataFromHex(dictionary[@"transaction_hex"]);

        NSAssert(txhash, @"Tx hash must be returned");
        NSAssert(txdata, @"Raw tx data in hex must be returned");

        BTCTransaction* tx = [[BTCTransaction alloc] initWithData:txdata];

        NSAssert([tx.transactionHash isEqual:txhash], @"Hashes must match.");

        completionHandler(tx, nil);
    }];
}



#pragma mark - Transaction Builder


// Builds, signs and sends transaction in one call.
// Response is the same as from `-sendTransaction:completionHandler:` call.
// {
//   inputs: [ {
//       private_key: "568fjdk2..." or BTCKey
//     }, {
//       private_key: "5fi654kd.." or BTCKey
//     }
//   ],
//   outputs: [ {
//       address: "1f72j...",
//       amount: 60000
//     }, {
//       address: "14g37...",
//       amount: 80000
//     }
//   ]
// }
- (void) transact:(NSDictionary*)params completionHandler:(void (^)(BTCTransaction *tx, NSError *error))completionHandler
{
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert([params[@"inputs"] isKindOfClass:[NSArray class]]);
    NSParameterAssert([params[@"outputs"] isKindOfClass:[NSArray class]]);

    ChainSigner* signer = [[ChainSigner alloc] initWithBlockchain:self.blockchain];
    NSDictionary* keysMap = [signer extractKeysFromInputs:params[@"inputs"]];

    if (!keysMap)
    {
        [NSException raise:@"ChainException" format:@"-transact: inputs must contain private keys"];
    }

    NSMutableDictionary* params2 = [params mutableCopy];
    NSMutableArray* inputs = [NSMutableArray array];
    for (NSString* address in keysMap) {
        [inputs addObject:@{@"address": address}];
    }
    params2[@"inputs"] = inputs;

    [self buildTransaction:params2 completionHandler:^(NSDictionary *template, NSError *error) {

        if (!template) {
            completionHandler(nil, error);
            return;
        }
        NSDictionary* signedTemplate = [signer signTemplate:template keys:keysMap];
        [self sendTransaction:signedTemplate completionHandler:completionHandler];
    }];
}

// Makes a request to build a transaction with given parameters.
- (void) buildTransaction:(NSDictionary*)params completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler
{
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert([params[@"inputs"] isKindOfClass:[NSArray class]]);
    NSParameterAssert([params[@"outputs"] isKindOfClass:[NSArray class]]);

    NSMutableDictionary* body = [NSMutableDictionary dictionary];
    body[@"inputs"] = params[@"inputs"];
    body[@"outputs"] = params[@"outputs"];
    if (params[@"change_address"])    body[@"change_address"]    = params[@"change_address"];
    if (params[@"miner_fee_rate"])    body[@"miner_fee_rate"]    = params[@"miner_fee_rate"];
    if (params[@"min_confirmations"]) body[@"min_confirmations"] = params[@"min_confirmations"];

    NSURL *url = [self.connection URLWithPath:@"transactions/build"];

    [self.connection startPostTaskWithURL:url dictionary:body completionHandler:completionHandler];
}

// Signs transaction template received from `-buildTransaction:completionHandler:`
// with the given keys and returns the same structure with signatures filled in.
- (NSDictionary*) signTransactionTemplate:(NSDictionary*)template keys:(NSArray* /* {"private_key": <BTCKey> or <WIF NSString> } */)keys
{
    NSParameterAssert(template != nil);
    NSParameterAssert(keys != nil);

    ChainSigner* signer = [[ChainSigner alloc] initWithBlockchain:self.blockchain];
    NSDictionary* keysMap = [signer extractKeysFromInputs:keys];

    return [signer signTemplate:template keys:keysMap];
}




#pragma mark - Blocks


- (void) getBlockHeader:(id)block completionHandler:(void (^)(BTCBlockHeader *blockHeader, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(block != nil);

    NSString* blockid = [ChainHelpers blockIDForBlockArgument:block];

    NSString *pathString = [NSString stringWithFormat:@"blocks/%@", blockid];
    NSURL *url = [self.connection URLWithPath:pathString];
    [self.connection startGetTaskWithURL:url completionHandler:^(NSDictionary *dictionary, NSError *error) {
        if (!dictionary) {
            completionHandler(nil, error);
            return;
        }
        BTCBlockHeader* bh = [ChainHelpers blockHeaderWithDictionary:dictionary error:&error];
        completionHandler(bh, bh ? nil : error);
    }];
}

- (void) getBlockHeaderByHeight:(NSInteger)height completionHandler:(void (^)(BTCBlockHeader *blockHeader, NSError *error))completionHandler {
    [self getBlockHeader:@(height) completionHandler:completionHandler];
}

- (void) getLatestBlockHeader:(void (^)(BTCBlockHeader *blockHeader, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);

    NSString *pathString = [NSString stringWithFormat:@"blocks/latest"];
    NSURL *url = [self.connection URLWithPath:pathString];
    [self.connection startGetTaskWithURL:url completionHandler:^(NSDictionary *dictionary, NSError *error) {
        if (!dictionary) {
            completionHandler(nil, error);
            return;
        }
        BTCBlockHeader* bh = [ChainHelpers blockHeaderWithDictionary:dictionary error:&error];
        completionHandler(bh, bh ? nil : error);
    }];
}

- (void) getBlock:(id)block completionHandler:(void (^)(BTCBlock *block, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(block != nil);

    [self getBlockHeader:block completionHandler:^(BTCBlockHeader *blockHeader, NSError *error) {
        if (!blockHeader) {
            completionHandler(nil, error);
            return;
        }
        [self getFullBlock:blockHeader completionHandler:completionHandler];
    }];
}

- (void) getLatestBlock:(void (^)(BTCBlock *block, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);

    [self getLatestBlockHeader:^(BTCBlockHeader *blockHeader, NSError *error) {
        if (!blockHeader) {
            completionHandler(nil, error);
            return;
        }
        [self getFullBlock:blockHeader completionHandler:completionHandler];
    }];
}


// Helper to load all txs for a given block header.
- (void) getFullBlock:(BTCBlockHeader*)bh completionHandler:(void (^)(BTCBlock *block, NSError *error))completionHandler {
    NSParameterAssert(completionHandler != nil);
    NSParameterAssert(bh != nil);

    __block int requestsCount = 0;

    BTCBlock* block = [[BTCBlock alloc] initWithHeader:bh];
    NSMutableArray* txs = [NSMutableArray array];

    for (NSString* txid in bh.userInfo[@"transactionIDs"]) {

        [txs addObject:[NSNull null]]; // placeholder
        NSUInteger txindex = txs.count - 1;

        requestsCount++;
        [self getTransaction:txid completionHandler:^(BTCTransaction *transaction, NSError *error) {
            if (requestsCount == 0) return; // all calls were cancelled.

            if (!transaction) {
                requestsCount = 0; // cancel and fail.
                completionHandler(nil, error);
                return;
            }

            requestsCount--;
            txs[txindex] = transaction;
            if (requestsCount == 0) {
                block.transactions = txs;
                completionHandler(block, nil);
            }
        }];
    }

    if (requestsCount == 0) {
        completionHandler(block, nil);
    }
}







#pragma mark - Notifications


- (ChainNotificationObserver*) observerForNotification:(ChainNotification*)notification
{
    return [self observerForNotification:notification resultHandler:nil];
}

- (ChainNotificationObserver*) observerForNotification:(ChainNotification*)notification resultHandler:(void(^)(ChainNotificationResult*))resultHandler
{
    NSParameterAssert(notification);

    return [self observerForNotifications:@[ notification ] resultHandler:resultHandler];
}

- (ChainNotificationObserver*) observerForNotifications:(NSArray*)notifications
{
    return [self observerForNotifications:notifications resultHandler:nil];
}

- (ChainNotificationObserver*) observerForNotifications:(NSArray*)notifications resultHandler:(void(^)(ChainNotificationResult*))resultHandler
{
    NSParameterAssert(notifications);

    ChainNotificationObserver* observer = [[ChainNotificationObserver alloc] initWithNotifications:notifications connection:self.connection];
    observer.resultHandler = resultHandler;
    [observer connect];
    return observer;
}


@end