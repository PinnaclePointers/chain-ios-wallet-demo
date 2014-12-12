# Chain

The Official iOS SDK for Chain's Bitcoin API.

## Install

Chain is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```
pod 'Chain', '~>2.0'
```

## Quick Start

```objc
Chain *chain = [Chain sharedInstanceWithToken:@"GUEST-TOKEN"];

NSString *address = @"1A3tnautz38PZL15YWfxTeh8MtuMDhEPVB";

[chain getAddress:address completionHandler:^(NSDictionary *dict, NSError *error) {
  NSLog(@"data=%@ error=%@", dict, error);
}];
```

## Documentation

The Chain API Documentation is available at [https://chain.com/docs/ios](https://chain.com/docs/ios)

## Developing Chain-iOS

This project uses CocoaPods for end-user app, but for its own static lib and
unit tests uses dependencies directly (CoreBitcoin submodule with OpenSSL).

These dependencies are not needed for the end-user, they will automatically link
via CocoaPods. But for running unit tests you have to checkout submodule and
build OpenSSL:

```bash
$ git submodule update --init
$ cd CoreBitcoin
$ ./update_openssl.sh
```

## Publishing a CocoaPod

```bash
$ git tag X.Y.Z
$ git push origin master --tags
$ pod trunk push Chain.podspec
```
