<img src="https://s3.amazonaws.com/chain-assets/chain-wallet-banner.png" style="width:100%"/>

# Chain iOS Wallet Demo

A Touch ID iOS Bitcoin wallet built on the [Chain API](https://chain.com).

## Summary
This open source Bitcoin wallet stores your private key in the iOS Keychain which is backed up on iCloud.
The private key can be restored with your Apple ID and unlocked for each payment with a fingerprint (using the TouchID).

Fork it and build something great!

## Launching the app
Chain Wallet uses the [Chain API iOS SDK](https://github.com/chain-engineering/chain-ios) and [CoreBitcoin](https://github.com/oleganza/CoreBitcoin), both included as CocoaPods.

The pods are already installed. To start, simply open the workspace file:

```
Chain Wallet.xcworkspace
```

Finally, get a Chain API token at [Chain.com](https://chain.com) and define the following in CNAppDelegate.m:

```
[Chain sharedInstanceWithToken:@"{YOUR-API-TOKEN}"];
```

## Requirements
Chain Wallet requires iPhone with iOS 8 and Touch ID (currently available on the iPhone 5s, iPhone 6 and iPhone 6 Plus).

## About Chain
[Chain](https://chain.com) is a powerful API that makes it easy to build Bitcoin applications -
without managing complicated block chain infrastructure.
We believe that virtual currency is only the first of thousands of applications that will be built on the block chain,
and we are excited to provide the platform that allows you to focus on creating great products.

We want to understand your needs and build along side you.
So don’t hesitate to request features, make suggestions, or just [say hello](mailto:hello@chain.com).
