//
//  SendViewController.m
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "CNSendViewController.h"
#import "CNSecretStore.h"
#import <CoreBitcoin/CoreBitcoin.h>
#import <Chain/Chain.h>

@interface CNSendViewController () <BTCTransactionBuilderDataSource>
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *sendButton;
@property (weak, nonatomic) IBOutlet UITextField *amountTextField;
@property (weak, nonatomic) IBOutlet UILabel *sentToAddressLabel;
@property (weak, nonatomic) IBOutlet UILabel *amountAvailable;

@property (nonatomic) BTCAmount balance;
@property (nonatomic) NSArray* unspentOutputs;
@property (nonatomic) BTCKey* unlockedKey;
@property (nonatomic) ChainNotificationObserver* addressObserver;
@end

@implementation CNSendViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.sentToAddressLabel.text = self.address.string;
    self.amountAvailable.text = @"";

    if (self.amount > 0) {
        self.amountTextField.text = [self formattedAmount:self.amount];
    }

    [self updateCoins:nil];
    [self updateObserver];
    [self.amountTextField becomeFirstResponder];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.addressObserver disconnect];
    self.addressObserver = nil;
}

- (BTCAddress*) walletAddress {
    return [CNSecretStore chainSecretStore].currentAddress;
}

- (BTCAmount) feeRate {
    return 1000;
}

- (BTCNumberFormatter*) btcFormatter {
    return [[BTCNumberFormatter alloc] initWithBitcoinUnit:BTCNumberFormatterUnitBTC symbolStyle:BTCNumberFormatterSymbolStyleSymbol];
}

- (BTCAmount) spendingAmount {
    return [self.btcFormatter amountFromString:self.amountTextField.text];
}

- (BTCAmount) remainingBalance {
    return self.balance - self.feeRate - self.spendingAmount;
}

- (NSString*) formattedAmount:(BTCAmount) amount {
    return [self.btcFormatter stringFromAmount:amount];
}



#pragma mark - Update Methods



- (void) updateCoins:(void(^)())block {

    [[Chain sharedInstance] getAddressUnspents:self.walletAddress completionHandler:^(NSArray *unspentOutputs, NSError *error) {
        if (unspentOutputs) {
            self.unspentOutputs = unspentOutputs;

            self.balance = 0;
            for (ChainTransactionOutput* txout in unspentOutputs) {
                self.balance += txout.value;
            }
            
            [self updateBalance];
        }
        if (block) block();
    }];
}

- (void) updateBalance {
    BTCAmount rem = self.remainingBalance;
    if (rem >= 0) {
        self.amountAvailable.text = [NSString stringWithFormat:@"%@ available", [self formattedAmount:rem]];
    } else {
        self.amountAvailable.text = NSLocalizedString(@"Not enough coins.", @"");
    }
}

- (void) updateObserver {
    [self.addressObserver disconnect];
    // Listen to new transactions on this address and update balance as needed.
    __weak __typeof(self) weakself = self;
    self.addressObserver = [[Chain sharedInstance] observerForNotification:
                            [[ChainNotification alloc] initWithAddress:self.walletAddress]
                                                             resultHandler:^(ChainNotificationResult *notification) {
                                                                 [weakself updateCoins:nil];
                                                             }];
}

- (void) showSendingSpinner {
    UIActivityIndicatorView *ai = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:ai];
    [ai startAnimating];
}

- (void) showSendButton {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStylePlain target:self.sendButton action:@selector(send:)];
}



#pragma mark - Actions


- (IBAction)amountDidChange:(id)sender {

    [self updateBalance];

    if (self.spendingAmount > 0) {
        [self.sendButton setEnabled:YES];
    } else {
        [self.sendButton setEnabled:NO];
    }
}

- (IBAction)send:(id)sender {

    [self showSendingSpinner];

    [self updateCoins:^{
        BTCAmount amount = self.spendingAmount;
        BTCAddress* address = self.address;

        if (amount == 0 || self.remainingBalance < 0) return;

        NSString* reason = [NSString stringWithFormat:NSLocalizedString(@"Send %@ to %@?", @""),
                            [self formattedAmount:amount], address.string];

        [[CNSecretStore chainSecretStore] unlock:^id(CNSecretStore *store, NSError **errorOut) {
            return store.key;
        } reason:reason completionBlock:^(id result, NSError *error) {
            if (result) {
                self.unlockedKey = result;

                [self sendAmount:amount to:address];

                [self.unlockedKey clear];
                self.unlockedKey = nil;
            }
        }];
    }];
}

- (IBAction)cancel:(id)sender {
    [self.amountTextField resignFirstResponder];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}




#pragma mark - Send Helpers



- (void)sendAmount:(BTCAmount)amount to:(BTCAddress*)address {

    BTCTransactionBuilder* builder = [[BTCTransactionBuilder alloc] init];
    builder.outputs = @[ [[BTCTransactionOutput alloc] initWithValue:amount address:address] ];
    builder.changeAddress = self.walletAddress;
    builder.feeRate = self.feeRate;
    builder.dataSource = self;

    NSError* berror = nil;
    BTCTransactionBuilderResult* result = nil;

    result = [builder buildTransaction:&berror];

    if (!result) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",@"")
                                    message:NSLocalizedString(@"Cannot spend funds.", @"")
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"OK",@"")
                          otherButtonTitles:nil] show];
        return;
    }

    [self broadcastTransaction:result.transaction];
}

- (void) broadcastTransaction:(BTCTransaction*)tx {

    [self showSendingSpinner];

    [[Chain sharedInstance] sendTransaction:tx completionHandler:^(ChainTransaction *tx, NSError *error) {

        [self showSendButton];

        if (!tx) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",@"")
                                        message:error.localizedDescription ?: NSLocalizedString(@"Failed to send transaction.", @"")
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"OK",@"")
                              otherButtonTitles:nil] show];
            return;
        }

        [self.amountTextField resignFirstResponder];
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }];
}



#pragma mark - BTCTransactionBuilderDataSource


- (NSEnumerator* /* [BTCTransactionOutput] */) unspentOutputsForTransactionBuilder:(BTCTransactionBuilder*)txbuilder
{
    return [self.unspentOutputs objectEnumerator];
}

- (BTCKey*) transactionBuilder:(BTCTransactionBuilder*)txbuilder keyForUnspentOutput:(BTCTransactionOutput*)txout
{
    return self.unlockedKey;
}






@end
