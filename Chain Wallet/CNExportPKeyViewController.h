//
//  CNExportPKeyViewController.h
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <CoreBitcoin/CoreBitcoin.h>

@interface CNExportPKeyViewController : UIViewController <MFMessageComposeViewControllerDelegate, UIActionSheetDelegate>

@property(nonatomic) BTCKey* privateKey;
@end
