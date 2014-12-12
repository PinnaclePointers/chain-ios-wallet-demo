//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "Chain.h"
#import "ChainHelpers.h"
#import <CoreBitcoin/CoreBitcoin.h>
#import <ISO8601DateFormatter.h>

@implementation ChainHelpers

+ (NSString*) addressStringForAddress:(id)addr {
    if ([addr isKindOfClass:[BTCAddress class]])
    {
        return ((BTCAddress*)addr).base58String;
    }
    else if ([addr isKindOfClass:[NSString class]])
    {
        return addr;
    }
    else
    {
        [NSException raise:@"Chain: unsupported address type"
                    format:@"Addresses must be of type NSString or BTCAddress. Unsupported type detected: %@", [addr class]];
    }
    return nil;
}

+ (NSArray*) addressStringsForAddresses:(NSArray*)addrs {
    NSMutableArray* addrStrings = [NSMutableArray array];
    for (id addr in addrs) {
        NSString* s = [self addressStringForAddress:addr];
        [addrStrings addObject:s];
    }
    return addrStrings;
}

+ (NSArray*) addressesForAddressStrings:(NSArray*)addressStrings {
    NSMutableArray* addresses = [NSMutableArray array];
    for (id str in addressStrings)
    {
        BTCAddress* addr = [BTCAddress addressWithBase58String:str];
        if (!addr) return nil;
        [addresses addObject:addr];
    }
    return addresses;
}

+ (BTCTransaction*) transactionWithDictionary:(NSDictionary*)dict {
    return [self transactionWithDictionary:dict allowTruncated:NO];
}

+ (BTCTransaction*) transactionWithDictionary:(NSDictionary*)dict allowTruncated:(BOOL)allowTruncated {
    // Will be used below to check that we constructed transaction correctly.
    NSData* receivedHash = BTCHashFromID(dict[@"hash"]);

    BTCTransaction* tx = [[BTCTransaction alloc] init];

    tx.lockTime = [dict[@"lock_time"] unsignedIntValue];

    for (NSDictionary* inputDict in dict[@"inputs"]) {
        BTCTransactionInput* txin = [self transactionInputWithDictionary:inputDict];
        [tx addInput:txin];
    }

    for (NSDictionary* outputDict in dict[@"outputs"]) {
        BTCTransactionOutput* txout = [self transactionOutputWithDictionary:outputDict];
        [tx addOutput:txout];
    }

    // Check that hash of the resulting tx is the same as received one.
    if (![tx.transactionHash isEqual:receivedHash]) {
        if (!allowTruncated)
        {
            NSLog(@"Chain: received transaction %@ and failed to build a proper binary copy. Could be non-canonical PUSHDATA somewhere. Dictionary: %@", dict[@"hash"], dict);
            NSAssert([tx.transactionHash isEqual:receivedHash], @"Transaction hash must match the declared hash.");
        }
        return nil;
    }

    ISO8601DateFormatter* dateFormatter = [[ISO8601DateFormatter alloc] init];

    tx.blockHash = BTCHashFromID([ChainHelpers filterNSNull:dict[@"block_hash"]]);
    tx.blockHeight = [[ChainHelpers filterNSNull:dict[@"block_height"]] integerValue];
    NSString* block_time = [ChainHelpers filterNSNull:dict[@"block_time"]];
    if (block_time) {
        tx.blockDate = [dateFormatter dateFromString:block_time];
    }
    tx.confirmations = [[ChainHelpers filterNSNull:dict[@"confirmations"]] integerValue];
    NSNumber* feeNumber = [ChainHelpers filterNSNull:dict[@"fees"]];
    if (feeNumber) {
        tx.fee = [feeNumber longLongValue];
    }
    NSString* chainReceivedDateString = [ChainHelpers filterNSNull:dict[@"chain_received_at"]];
    NSDate* chainReceivedDate = chainReceivedDateString ? [dateFormatter dateFromString:chainReceivedDateString] : nil;

    if (chainReceivedDate) {
        tx.userInfo = @{
            @"chain_received_at": chainReceivedDate
        };
    }
    return tx;
}

+ (BTCTransactionInput*) transactionInputWithDictionary:(NSDictionary*)inputDict {
    BTCTransactionInput* txin = [[BTCTransactionInput alloc] init];

    NSString* scriptSig = [self filterNSNull:inputDict[@"script_signature"]];
    NSString* coinbaseHex = [self filterNSNull:inputDict[@"coinbase"]];

    if (!scriptSig && coinbaseHex)
    {
        txin.coinbaseData = BTCDataFromHex(coinbaseHex);
    }
    else
    {
        txin.previousTransactionID = inputDict[@"output_hash"];
        txin.previousIndex = [inputDict[@"output_index"] unsignedIntValue];
        txin.signatureScript = [[BTCScript alloc] initWithString:scriptSig];
        NSAssert(txin.signatureScript, @"Must have non-nil script signature");
    }

    txin.sequence = [inputDict[@"sequence"] unsignedIntValue];

    txin.userInfo = @{
                      @"addresses": [self addressesForAddressStrings:inputDict[@"addresses"]],
                      };
    txin.value = [inputDict[@"value"] longLongValue];
    return txin;
}

+ (BTCTransactionOutput*) transactionOutputWithDictionary:(NSDictionary*)outputDict {
    BTCTransactionOutput* txout = [[BTCTransactionOutput alloc] init];
    txout.value = [outputDict[@"value"] longLongValue];
    txout.script = [[BTCScript alloc] initWithData:BTCDataFromHex(outputDict[@"script_hex"])];
    txout.userInfo = @{
                       @"addresses": [self addressesForAddressStrings:outputDict[@"addresses"]],
                       };
    txout.spent = [outputDict[@"spent"] boolValue];

    // Available in unspents API
    if (outputDict[@"confirmations"] && outputDict[@"confirmations"] != [NSNull null]) {
        txout.confirmations = [outputDict[@"confirmations"] unsignedIntegerValue];
    }

    // Available in unspents API
    if (outputDict[@"output_index"] && outputDict[@"output_index"] != [NSNull null]) {
        txout.index = [outputDict[@"output_index"] unsignedIntValue];
    }
    txout.transactionID = [ChainHelpers filterNSNull:outputDict[@"transaction_hash"]];

    return txout;
}

+ (NSArray*) opreturnsWithDictionaries:(NSArray*) dicts error:(NSError**)errorOut {

    if (!dicts) {
        if (errorOut) *errorOut = [NSError errorWithDomain:ChainErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Missing OP_RETURNs."}];
        return nil;
    }

    NSMutableArray* opreturns = [NSMutableArray array];
    for (NSDictionary* dict in dicts) {
        ChainOpReturn* opreturn = [[ChainOpReturn alloc] initWithDictionary:dict];
        if (!opreturn) {
            if (errorOut) *errorOut = [NSError errorWithDomain:ChainErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Invalid OP_RETURN data."}];
            return nil;
        }
        [opreturns addObject:opreturn];
    }

    return opreturns;
}

+ (NSString*) blockIDForBlockArgument:(id)block {

    if ([block isKindOfClass:[NSString class]]) { // block id
        return block;
    } else if ([block isKindOfClass:[NSNumber class]]) { // height
        return block;
    } else if ([block isKindOfClass:[NSData class]]) { // hash
        return BTCIDFromHash(block);
    } else if ([block isKindOfClass:[BTCBlock class]]) {
        return [(BTCBlock*)block blockID];
    } else if ([block isKindOfClass:[BTCBlockHeader class]]) {
        return [(BTCBlockHeader*)block blockID];
    } else {
        [NSException raise:@"ChainException" format:@"Unexpected type for block identifier: %@", [block class]];
    }
    return nil;
}

+ (BTCBlockHeader*) blockHeaderWithDictionary:(NSDictionary*)dict error:(NSError**)errorOut {

    /*
     {
     "hash": "00000000000004099303e4ec0e4854dca15eeea112e855e6afe437e26f1910d3",
     "previous_block_hash": "0000000000000278f6c049cec04014ca44623032be15e587c447b1740f730725",
     "height": 146269,
     "confirmations": 186320,
     "version": 1,
     "merkle_root": "89ed3429766cdea59499b4d1f913a541f2309ea9fad4d496cdde095dca897d2b",
     "time": "2011-09-21T09:14:21.000Z",
     "nonce": 493165096,
     "difficulty": 1755425.3203287,
     "bits": "1a098ea5",
     "transaction_hashes": [
     "89ed3429766cdea59499b4d1f913a541f2309ea9fad4d496cdde095dca897d2b"
     ]
     }
     */

    // Will be used below to check that we reconstructed block header correctly.
    NSData* receivedHash = BTCHashFromID(dict[@"hash"]);

    BTCBlockHeader* bh = [[BTCBlockHeader alloc] init];
    bh.version = [dict[@"version"] intValue];
    bh.previousBlockID = [self filterNSNull:dict[@"previous_block_hash"]];
    bh.merkleRootHash = BTCHashFromID(dict[@"merkle_root"]);

    ISO8601DateFormatter* dateFormatter = [[ISO8601DateFormatter alloc] init];
    bh.time = (uint32_t)round([[dateFormatter dateFromString:dict[@"time"]] timeIntervalSince1970]);
    bh.nonce = [dict[@"nonce"] unsignedIntValue];
    NSData* bitsDataLE = BTCReversedData(BTCDataFromHex(dict[@"bits"]));
    if (bitsDataLE.length < 4) {
        NSMutableData* d2 = [bitsDataLE mutableCopy];
        d2.length = 4; // setter zero-fills extra bytes.
        bitsDataLE = d2;
    }
    bh.difficultyTarget = *((uint32_t*)bitsDataLE.bytes);

    // Check that hash of the resulting tx is the same as received one.
    if (![bh.blockHash isEqual:receivedHash]) {
        NSLog(@"Chain: received block header %@ and failed to build a proper binary copy. Dictionary: %@", dict[@"hash"], dict);
        NSAssert([bh.blockHash isEqual:receivedHash], @"Block header hash must match the declared hash.");
        if (errorOut) *errorOut = [NSError errorWithDomain:ChainErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Invalid block header: hashes do not match."}];
        return nil;
    }

    // Info properties:

    bh.height = [dict[@"height"] integerValue];
    bh.confirmations = [dict[@"confirmations"] unsignedIntegerValue];
    bh.userInfo = @{@"transactionIDs": dict[@"transaction_hashes"] ?: @[]};
    return bh;
}

+ (id) filterNSNull:(id)obj {
    if (obj == [NSNull null]) return nil;
    return obj;
}

@end
