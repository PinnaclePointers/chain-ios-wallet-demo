//
//  HomeViewController.m
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//
#import <Chain/Chain.h>
#import <CoreBitcoin/CoreBitcoin+Categories.h>

#import "CNHomeViewController.h"
#import "CNSendViewController.h"
#import "CNExportPKeyViewController.h"
#import "CNSecretStore.h"
#import "UIColor+Additions.h"
#import "NSString+Additions.h"


@interface CNHomeViewController () <UIActionSheetDelegate, UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, readonly) BTCAddress* address;
@property(nonatomic) NSArray *transactions;
@property(nonatomic) BTCAmount balance;
@property(nonatomic) ChainNotificationObserver* addressObserver;
@property(nonatomic) UIView* scannerView;
@property(nonatomic, weak) IBOutlet UITableView *tableView;
@property(nonatomic, weak) IBOutlet UILabel *noTransactionsLabel;
@end

@implementation CNHomeViewController

- (void)dealloc {
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self updateLabels];
    [self updateBalance];
    [self updateTransactions];
    [self updateObserver];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [self.addressObserver disconnect];
    self.addressObserver = nil;
}


#pragma mark - Properties


- (BTCAddress*) address {
    return [CNSecretStore chainSecretStore].currentAddress;
}



#pragma mark - Actions


- (IBAction) send:(id)sender {

    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Send to address", @"")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Scan QR code" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showQRScanner];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Paste from clipboard" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self pasteFromClipboard];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction) receive:(id)sender {
    // See storyboard segue.
}

- (IBAction) options:(id)sender {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Options", @"")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Visit Chain.com" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://chain.com"]];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"View source code" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/chain-engineering/chain-ios-wallet-demo"]];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Export private key" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[CNSecretStore chainSecretStore] unlock:^id(CNSecretStore *store, NSError **errorOut) {
            BTCKey* key = store.key;
            if (!key) *errorOut = store.error;
            return key;
        } reason:NSLocalizedString(@"Authenticate to export your private key.", @"")
                                 completionBlock:^(id key, NSError *error) {
                                     if (key) {
                                         [self exportKey:key];
                                     }
                                 }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}


- (void) showQRScanner {
    __weak __typeof(self) weakself = self;
    self.scannerView = [BTCQRCode scannerViewWithBlock:^(NSString *message) {
        // Try to check if it's a raw address
        BTCAddress* address = [BTCAddress addressWithString:message];
        if (address) {
            [weakself finishScanning];
            [weakself sendToAddress:address amount:0];
            return;
        }
        // Check if it's a bitcoin URL with address and potentially an amount.
        BTCBitcoinURL* url = [[BTCBitcoinURL alloc] initWithURL:[NSURL URLWithString:message]];
        if (url) {
            [weakself finishScanning];
            [weakself sendToAddress:url.address amount:url.amount];
            return;
        }
    }];

    // Simply display full-screen and tap anywhere to dismiss.

    [self.view addSubview:self.scannerView];
    self.scannerView.frame = self.view.bounds;
    self.scannerView.userInteractionEnabled = YES;
    UITapGestureRecognizer* cancelTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(finishScanning)];
    [self.scannerView addGestureRecognizer:cancelTap];
}

- (void) finishScanning {
    [self.scannerView removeFromSuperview];
    self.scannerView = nil;
}

- (void) pasteFromClipboard {
    // Get the contents of the device clipboard.
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    BTCAddress* address = [BTCAddress addressWithString:pasteboard.string];

    if (!address) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Oops!", @"")
                                    message:NSLocalizedString(@"Clipboard does not contain a valid Bitcoin address", @"")
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"OK", @"")
                          otherButtonTitles:nil] show];
        return;
    }

    [self sendToAddress:address amount:0];
}

- (void) exportKey:(BTCKey*)key {
    UINavigationController *exportNavigationController = [self.storyboard instantiateViewControllerWithIdentifier:@"exportNavController"];
    CNExportPKeyViewController* evc = (CNExportPKeyViewController*)exportNavigationController.topViewController;
    evc.privateKey = key;
    [self presentViewController:exportNavigationController animated:YES completion:nil];
}

- (void) sendToAddress:(BTCAddress*)address amount:(BTCAmount)amount {

    UINavigationController *sendNavigationController = [self.storyboard instantiateViewControllerWithIdentifier:@"sendNavController"];
    CNSendViewController *svc = (CNSendViewController *)sendNavigationController.topViewController;
    svc.address = address;
    svc.amount = amount;
    [self presentViewController:sendNavigationController animated:YES completion:nil];
}



#pragma mark - Updates


- (void) updateTransactions {
    self.noTransactionsLabel.text = NSLocalizedString(@"Loading...", @"");
    [[Chain sharedInstance] getAddressTransactions:self.address limit:10 completionHandler:^(NSArray *transactions, NSError *error) {
        if (transactions) {
            self.transactions = transactions;
            self.noTransactionsLabel.text = NSLocalizedString(@"No Transactions", @""); // will be visible if txs.count == 0
            [self.tableView reloadData];
        } else {
            self.noTransactionsLabel.text = NSLocalizedString(@"Network Error", @"");
        }
    }];
}

- (void) updateBalance {
    [[Chain sharedInstance] getAddress:self.address completionHandler:^(ChainAddressInfo *addressInfo, NSError *error) {
        if (addressInfo) {
            self.balance = addressInfo.totalBalance;
        }
    }];
}

- (void) updateObserver {
    [self.addressObserver disconnect];
    // Listen to new transactions on this address and update balance as needed.
    __weak __typeof(self) weakself = self;
    self.addressObserver = [[Chain sharedInstance] observerForNotification:
                            [[ChainNotification alloc] initWithAddress:self.address]
                                                             resultHandler:^(ChainNotificationResult *notification) {

                                                                 if ([notification isKindOfClass:[ChainNotificationAddress class]]) {
                                                                     // Instantly adjust the balance based on notification.
                                                                     ChainNotificationAddress* addrNotif = (ChainNotificationAddress*)notification;
                                                                     weakself.balance = weakself.balance + addrNotif.receivedAmount - addrNotif.sentAmount;

                                                                     // For good measure update the balance with a canonical request.
                                                                     // If we don't do that, and miss some notifications, our balance will become irrelevant.
                                                                     // Same for transactions.
                                                                     [weakself updateBalance];
                                                                     [weakself updateTransactions];
                                                                 }
                                                             }];
}

- (void) setTransactions:(NSArray *)transactions {
    _transactions = transactions;
    [self updateLabels];
}

- (void) setBalance:(BTCAmount)balance {
    _balance = balance;
    self.title = [self formattedAmount:_balance];
}

- (NSString*) formattedAmount:(BTCAmount) amount {
    BTCNumberFormatter* fmt = [[BTCNumberFormatter alloc] initWithBitcoinUnit:BTCNumberFormatterUnitBTC symbolStyle:BTCNumberFormatterSymbolStyleSymbol];
    return [fmt stringFromAmount:amount];
}

- (void) updateLabels {
    self.noTransactionsLabel.hidden = (_transactions.count > 0);
    self.tableView.hidden = !self.noTransactionsLabel.hidden;
}




#pragma mark - UITableViewDataSource



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.transactions.count;
}

// We set this to match the custom cell height from the storyboard
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"transactionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    BTCTransaction *tx = self.transactions[indexPath.row];
    
    // Pointers for Cell Values
    UILabel *amountLabel = (UILabel *)[cell.contentView viewWithTag:1];
    UILabel *addressLabel = (UILabel *)[cell.contentView viewWithTag:2];
    UILabel *dateLabel = (UILabel *)[cell.contentView viewWithTag:3];

    NSAssert(amountLabel, @"sanity check");
    NSAssert(addressLabel, @"sanity check");
    NSAssert(dateLabel, @"sanity check");

    // Transaction Date Formatter
    NSString *localDateString = @"";
    if (tx.blockDate) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.timeZone = [NSTimeZone systemTimeZone];
        fmt.timeStyle = NSDateFormatterNoStyle;
        fmt.dateStyle = NSDateFormatterShortStyle;
        localDateString = [fmt stringFromDate:tx.blockDate];
    }
    
    // Show Date (if confirmed) or 'Pending' (if not confirmed)
    NSInteger transactionConfirmations = tx.confirmations;
    if (transactionConfirmations == 0) {
        dateLabel.text = @"Pending";
    } else {
        dateLabel.text = localDateString;
    }
    
    // Transaction Amount
    BTCAmount txValue = [self valueForTransactionForCurrentUser:tx];
    amountLabel.text = [self formattedAmount:txValue];
    
    // Change Color of Transaction Amount if is sent or received or to self
    BOOL isTransactionToSelf = [self isTransactionToSelf:tx];
    if (isTransactionToSelf) {
        amountLabel.textColor = [UIColor colorWithHex:0x7d2b8b];
        addressLabel.text = @"To: myself";
    } else {
        if (txValue < 0) {
            // Sent
            amountLabel.textColor = [UIColor colorWithHex:0xf76b6b];
            addressLabel.text = [NSString stringWithFormat:@"To: %@", [self outputAddressesString:tx]];
        } else {
            // Receive
            amountLabel.textColor = [UIColor colorWithHex:0x7fdf40];
            addressLabel.text = [NSString stringWithFormat:@"From: %@", [self inputAddressesString:tx]];
        }
    }
    
    return cell;
}



#pragma mark - Helpers



- (BOOL) isTransactionToSelf:(BTCTransaction *)tx {
    // If all inputs and outputs are wallet's address.
    NSMutableArray *addresses = [NSMutableArray array];

    for (BTCTransactionInput *txin in tx.inputs) {
        [addresses addObjectsFromArray:txin.userInfo[@"addresses"]];
    }
    for (BTCTransactionOutput *txout in tx.outputs) {
        [addresses addObjectsFromArray:txout.userInfo[@"addresses"]];
    }
    
    // Removes wallet address and duplicate addresses. A count of zero means wallet address was included.
    NSArray *filteredAddresses = [self filteredAddresses:addresses];
    return (filteredAddresses.count == 0);
}

- (BTCAmount) valueForInputOrOutput:(id)txinOrTxout {
    NSArray *addresses = [txinOrTxout userInfo][@"addresses"];
    for (BTCAddress *address in addresses) {
        if ([address isEqual:self.address]) {
            return [[txinOrTxout valueForKey:@"value"] longLongValue];
        }
    }
    return 0;
}

- (BTCAmount)valueForTransactionForCurrentUser:(BTCTransaction *)tx {
    BTCAmount valueForWallet = 0;
    if ([self isTransactionToSelf:tx]) {
        // If sending to self, we assume the first output is the amount to display and other is change.
        NSArray *outputs = [tx valueForKey:@"outputs"];
        if ([outputs count] >= 1) {
            valueForWallet = [[[outputs firstObject] valueForKey:@"value"] integerValue];
        }
    } else {
        // Iterate inputs calculating total sent in transaction.
        BTCAmount amountSent = 0;
        for (BTCTransactionInput *txin in tx.inputs) {
            amountSent = amountSent + [self valueForInputOrOutput:txin];
        }
        
        // Iterate outputs calculating total received in transaction.
        BTCAmount amountReceived = 0;
        for (BTCTransactionOutput *txout in tx.outputs) {
            amountReceived = amountReceived + [self valueForInputOrOutput:txout];
        }
        
        valueForWallet = amountReceived - amountSent;
        // If it is sent, do not include fee.
        if (valueForWallet < 0) {
            valueForWallet = valueForWallet + tx.fee;
        }
    }
    
    return valueForWallet;
}

- (NSArray *) filteredAddresses:(NSArray *)addresses {
    // Remove duplicates.
    NSMutableArray *filteredAddressStrings = [NSMutableArray arrayWithArray:[[NSSet setWithArray:[addresses valueForKey:@"string"]] allObjects]];
    
    // Remove current user.
    [filteredAddressStrings removeObject:self.address.string];

    NSMutableArray* filteredAddresses = [NSMutableArray array];
    for (id str in filteredAddressStrings)
    {
        BTCAddress* addr = [BTCAddress addressWithString:str];
        if (!addr) return nil;
        [filteredAddresses addObject:addr];
    }
    return addresses;
}

- (NSString *) filteredTruncatedAddress:(NSArray *)addresses {
    NSArray *filteredAddresses = [self filteredAddresses:addresses];
    
    NSMutableString *addressString = [NSMutableString string];
    
    for (int i = 0; i < filteredAddresses.count; i++) {
        BTCAddress *address = [filteredAddresses objectAtIndex:i];
    
        // Truncate if we have more then one.
        if (filteredAddresses.count > 1) {
            NSString *shortenedAddress = address.string;
            shortenedAddress = [shortenedAddress substringToIndex:10];
            [addressString appendFormat:@"%@…", shortenedAddress];
        } else {
            [addressString appendFormat:@"%@", address.string];
        }
        
        // Add a comma and space if this is not the last
        if (i != filteredAddresses.count - 1) {
            [addressString appendFormat:@", "];
        }
    }
    
    return addressString;
}

- (NSString *) inputAddressesString:(BTCTransaction*)tx {
    NSMutableArray *addresses = [NSMutableArray array];
    for (BTCTransactionInput *txin in tx.inputs) {
        [addresses addObjectsFromArray:txin.userInfo[@"addresses"]];
    }
    return [self filteredTruncatedAddress:addresses];
}

- (NSString *) outputAddressesString:(BTCTransaction*)tx {
    NSMutableArray *addresses = [NSMutableArray array];
    for (BTCTransactionOutput *txout in tx.outputs) {
        [addresses addObjectsFromArray:txout.userInfo[@"addresses"]];
    }
    return [self filteredTruncatedAddress:addresses];
}

@end
