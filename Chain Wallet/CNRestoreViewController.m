//
//  CNRestoreViewController.m
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <CoreBitcoin/CoreBitcoin.h>
#import "CNSecretStore.h"
#import "CNRestoreViewController.h"
#import "CNAppDelegate.h"

@interface CNRestoreViewController ()

@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;

@end

@implementation CNRestoreViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
}

- (void) cancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)next:(id)sender {

    if (self.textField.text.length == 0) {
        return;
    }

    BTCKey* key = [[BTCKey alloc] initWithWIF:self.textField.text];

    if (!key) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"")
                                    message:NSLocalizedString(@"Invalid private key format", @"")
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"OK", @"")
                          otherButtonTitles:nil] show];
        return;
    }

    [[CNSecretStore chainSecretStore] unlock:^(CNSecretStore *store) {

        store.key = key;

    } reason:NSLocalizedString(@"Authenticate storing your private key.", @"")];

    BTCKey *pubkey = [CNSecretStore chainSecretStore].publicKey;

    // If we cannot read back the pubkey, we don't have the passcode/touchid set up correctly.
    if (!pubkey) {

        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Passcode Required", @"")
                                    message:NSLocalizedString(@"You should enable the passcode on your device to use Chain Wallet", @"")
                                   delegate:self
                          cancelButtonTitle:@"OK"
                          otherButtonTitles: nil] show];
        return;
    }

    [self.view endEditing:YES];
    [[CNAppDelegate sharedInstance] showHomeScreen];
}

- (IBAction)editingDidEnd:(id)sender {
    [self next:sender];
}



@end
