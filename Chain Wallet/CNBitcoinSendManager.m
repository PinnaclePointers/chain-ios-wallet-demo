//
//  CNBitcoinSendManager.m
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "CNBitcoinSendManager.h"
#import "Chain.h"
#import "CNSecretStore.h"
#import <UIKit/UIKit.h>
#import <CoreBitcoin/CoreBitcoin+Categories.h>
#import <CoreBitcoin/CoreBitcoin.h>

#define CHAIN_ERROR_DOMAIN @"com.Chain.Chain-Wallet.ErrorDomain"

@implementation CNBitcoinSendManager

+ (void)sendAmount:(BTCAmount)satoshiAmount receiveAddresss:(NSString *)receiveAddress fee:(BTCAmount)fee completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler {

    __block BTCKey* key = nil;
    __block NSError* error = nil;
    [[CNSecretStore chainSecretStore] unlock:^(CNSecretStore *store) {
        key = store.key;

        if (!key) {
            if (store.error && store.error.code != errSecUserCanceled) {
                error = store.error;
            }
        }

    } reason:NSLocalizedString(@"Authenticate to send Bitcoin", @"")];

    if (!key) {
        completionHandler(nil, error);
        return;
    }

    NSLog(@"Sending from Address: %@", [key.address string]);
    
    [CNBitcoinSendManager sendFromPrivateKey:key
                                          to:[BTCPublicKeyAddress addressWithString:receiveAddress]
                                      change:key.address
                                      amount:satoshiAmount
                                         fee:fee
                           completionHandler:^(BTCTransaction *transaction, NSError *error) {
        if (transaction) {
            [[Chain sharedInstance] sendTransaction:transaction completionHandler:^(BTCTransaction *tx, NSError *error) {
                completionHandler(tx.dictionary, error);
            }];
        } else {
            if (!error) {
                NSString *domain = @"com.Chain.Chain-Wallet.ErrorDomain";
                NSString *desciption = @"Unable to generate transaction.";
                NSDictionary *userInfo = @{NSLocalizedDescriptionKey : desciption};
                
                error = [NSError errorWithDomain:domain code:-101 userInfo:userInfo];
            }
            completionHandler(nil, error);
        }
    }];
}

// Based on CoreBitcoin / CoreBitcoin / BTCTransaction+Tests.m
+ (void)sendFromPrivateKey:(BTCKey *)privateKey to:(BTCPublicKeyAddress *)destinationAddress change:(BTCPublicKeyAddress *)changeAddress amount:(BTCAmount)amount fee:(BTCAmount)fee completionHandler:(void (^)(BTCTransaction *transaction, NSError *error))completionHandler {
    
    BTCKey *key = privateKey;
    
    NSString *sendingAddressString = key.address.string;
    [[Chain sharedInstance] getAddressUnspents:sendingAddressString completionHandler:^(NSArray* utxos, NSError *error) {
        if (!utxos) {
            completionHandler(nil, error);
        } else {
            // Find enough outputs to spend the total amount.
            BTCAmount totalAmount = amount + fee;
            
            // Sort utxo in order of amount.
            utxos = [utxos sortedArrayUsingComparator:^(BTCTransactionOutput* obj1, BTCTransactionOutput* obj2) {
                if ((obj1.value - obj2.value) < 0) return NSOrderedAscending;
                else return NSOrderedDescending;
            }];
            
            NSMutableArray *txouts = [NSMutableArray array];
            
            BTCAmount balance = 0;
            
            for (BTCTransactionOutput *txout in utxos) {
                if (txout.script.isPayToPublicKeyHashScript) {
                    [txouts addObject:txout];
                    balance = balance + txout.value;
                }
                if (balance >= totalAmount) {
                    break;
                }
            }
            
            // Check for insufficent funds.
            if (!txouts || balance < totalAmount) {
                NSString *errorDescription = [NSString stringWithFormat:@"Insufficient funds. Your balance of %llu is less than transaction amount:%llu", balance, totalAmount];
                NSDictionary *userInfo = @{NSLocalizedDescriptionKey : errorDescription};
                error = [NSError errorWithDomain:CHAIN_ERROR_DOMAIN code:-102 userInfo:userInfo];
                
                completionHandler(nil, error);
            } else {
                // Create a new transaction
                BTCTransaction *tx = [[BTCTransaction alloc] init];

                BTCAmount spentCoins = 0;
                
                // Add all outputs as inputs
                for (BTCTransactionOutput *txout in txouts) {
                    BTCTransactionInput *txin = [[BTCTransactionInput alloc] init];
                    txin.previousHash = txout.transactionHash;
                    txin.previousIndex = txout.index;
                    [tx addInput:txin];
                    
                    spentCoins += txout.value;
                }
                
                // Add required outputs - payment and change
                BTCTransactionOutput *paymentOutput = [[BTCTransactionOutput alloc] initWithValue:amount address:destinationAddress];
                BTCTransactionOutput *changeOutput = [[BTCTransactionOutput alloc] initWithValue:(spentCoins - totalAmount) address:changeAddress];
                
                [tx addOutput:paymentOutput];
                [tx addOutput:changeOutput];
                
                // Sign all inputs. We now have both inputs and outputs defined, so we can sign the transaction.
                for (int i = 0; i < txouts.count; i++) {
                    BTCTransactionOutput *txout = txouts[i]; // output from a previous tx which is referenced by this txin.
                    BTCTransactionInput *txin = tx.inputs[i];
                    
                    BTCScript *sigScript = [[BTCScript alloc] init];
                    NSData* hash = [tx signatureHashForScript:txout.script inputIndex:i hashType:BTCSignatureHashTypeAll error:&error];
                    
                    if (!hash) {
                        NSString *errorDescription = @"Unable to create a hash to sign the transctions.";
                        NSDictionary *userInfo = @{NSLocalizedDescriptionKey : errorDescription};
                        error = [NSError errorWithDomain:CHAIN_ERROR_DOMAIN code:-102 userInfo:userInfo];
                        
                        completionHandler (nil, error);
                        return;
                    } else {
                        NSData *signature = [key signatureForHash:hash];
                        
                        NSMutableData *signatureForScript = [signature mutableCopy];
                        unsigned char hashtype = BTCSignatureHashTypeAll;
                        [signatureForScript appendBytes:&hashtype length:1];
                        [sigScript appendData:signatureForScript];
                        [sigScript appendData:key.publicKey];
                        
                        txin.signatureScript = sigScript;
                    }
                }
                completionHandler(tx, error);
            }
        }
    }];
}

@end
