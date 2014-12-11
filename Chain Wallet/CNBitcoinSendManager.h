//
//  CNBitcoinSendManager.h
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBitcoin/CoreBitcoin+Categories.h>

@interface CNBitcoinSendManager : NSObject

+ (void)sendAmount:(BTCAmount)satoshiAmount receiveAddresss:(NSString *)receiveAddress fee:(BTCAmount)fee completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler;

@end
