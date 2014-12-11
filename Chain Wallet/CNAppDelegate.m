//
//  CNAppDelegate.m
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "CNAppDelegate.h"
#import "CNSecretStore.h"
#import "UIColor+Additions.h"

#import <Chain/Chain.h>
#import <CoreBitcoin/CoreBitcoin.h>

static NSString* CNSampleToken = @"2277e102b5d28a90700ff3062a282228";

@implementation CNAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

#warning TODO: Replace this sample token with your actual token.
    [Chain sharedInstanceWithToken:CNSampleToken];

    // Uncomment to test the welcome screen. Backup your private key first.
    if ((0)) {
        [[CNSecretStore chainSecretStore] unlock:^(CNSecretStore *store) {
            store.key = nil;
        } reason:NSLocalizedString(@"Authorize removing the private key", @"")];
    }

    // Style the navigation bar
    [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithHex:0x1293C2]];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    [[UINavigationBar appearance] setTitleTextAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                                                           [UIColor colorWithRed:245.0/255.0 green:245.0/255.0 blue:245.0/255.0 alpha:1.0], NSForegroundColorAttributeName,
                                                           [UIFont fontWithName:@"AvenirNext-Medium" size:18.0], NSFontAttributeName, nil]];
    
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];

    // Show welcome screen if we haven't generated an address.
    BTCKey* pubkey = [CNSecretStore chainSecretStore].publicKey;
    UIViewController *viewController  = nil;
    if (!pubkey) {
        viewController = [storyboard instantiateViewControllerWithIdentifier:@"welcomeViewController"];
    } else {
        viewController = [storyboard instantiateViewControllerWithIdentifier:@"transactionsNavigationController"];
    }
    
    self.window.rootViewController = viewController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
