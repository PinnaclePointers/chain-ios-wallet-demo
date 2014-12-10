//
//  CNAppDelegate.m
//  Chain Wallet
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "CNAppDelegate.h"
#import "CNSecretStore.h"
#import "Chain.h"
#import "UIColor+Additions.h"
#import <CoreBitcoin/CoreBitcoin.h>

@implementation CNAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // REPLACE THIS LIMITED "GUEST-TOKEN" WITH YOUR API TOKEN FROM CHAIN.COM
    [Chain sharedInstanceWithToken:@"2277e102b5d28a90700ff3062a282228"];
    
    // REMOVE THIS LINE AFTER DEFINING YOUR API TOKEN
    NSLog(@"\n!!!\nYOU ARE USING A LIMITED GUEST TOKEN FOR THE CHAIN API. PLEASE VISIT CHAIN.COM AND REGISTER TO RECIEVE YOUR PERSONAL API TOKEN.\n!!!\n");
    
    
    // Style the navigation bar
    [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithHex:0x12cae1]];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
    [[UINavigationBar appearance] setTitleTextAttributes: [NSDictionary dictionaryWithObjectsAndKeys:
                                                           [UIColor colorWithRed:245.0/255.0 green:245.0/255.0 blue:245.0/255.0 alpha:1.0], NSForegroundColorAttributeName,
                                                           [UIFont fontWithName:@"Avenir" size:21.0], NSFontAttributeName, nil]];
    
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    // Uncomment to test the welcome screen. Backup your private key first.
    if ((0)) {
        [[CNSecretStore chainSecretStore] unlock:^(CNSecretStore *store) {
            store.key = nil;
        } reason:NSLocalizedString(@"Authorize removing the private key", @"")];
    }

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
