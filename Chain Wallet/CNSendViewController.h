//
//  SendViewController.h
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBitcoin/CoreBitcoin.h>

@interface CNSendViewController : UIViewController <UIAlertViewDelegate>
@property (nonatomic) BTCAddress* address;
@property (nonatomic) BTCAmount amount;
@end
