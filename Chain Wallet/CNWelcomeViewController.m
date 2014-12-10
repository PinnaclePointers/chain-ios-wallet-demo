//
//  CNWelcomeViewController.m
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "CNWelcomeViewController.h"
#import "CNSecretStore.h"
#import <CoreBitcoin/CoreBitcoin.h>

@implementation CNWelcomeViewController

- (IBAction)generateAnAddressAction:(id)sender {

    [[CNSecretStore chainSecretStore] unlock:^(CNSecretStore *store) {

        BTCKey* key = [self generateRandomKey];
        store.key = key;

    } reason:NSLocalizedString(@"Authenticate creation of the secret key.", @"")];

    BTCKey *k = [CNSecretStore chainSecretStore].publicKey;
    NSLog(@"Generated address: %@ (%@)", k.publicKeyAddress, BTCHexStringFromData(k.publicKey));

    // If we cannot read
    if (!k) {

        [[[UIAlertView alloc] initWithTitle:@"Passcode Required" message:@"You should enable the passcode on your device to use Chain Wallet" delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
        return;
    }

    // Present transactions view contorller.
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"transactionsNavigationController"];
    [self presentViewController:viewController animated:YES completion:nil];
}

- (BTCKey*) generateRandomKey {

    NSUInteger length = 32;
    NSMutableData *secret = [NSMutableData dataWithLength:length];
    OSStatus sanityCheck = noErr;

    sanityCheck = SecRandomCopyBytes(kSecRandomDefault, length, secret.mutableBytes);
    if (sanityCheck != noErr) {
        NSLog(@"Issue generating a private key.");
    }

    NSAssert(secret.length == 32, @"secret must be 32 bytes long");
    BTCKey *key = [[BTCKey alloc] initWithPrivateKey:secret];
    
    return key;
}

@end
