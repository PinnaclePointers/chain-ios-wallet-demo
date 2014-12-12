//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ChainConnection : NSObject

@property(nonatomic) NSString* token;
@property(nonatomic) NSString* blockchain; // E.g. "bitcoin", see ChainBlockchainMainnet/Testnet
@property(nonatomic) NSString* version; // E.g. "v2"
@property(nonatomic) NSString* hostname;
@property(nonatomic) NSString* webSocketHostname;
@property(nonatomic, readonly) NSArray* anchorCertificates;

// Returns a fully-specified URL to make a request for a given path.
- (NSURL*) URLWithPath:(NSString *)path;

// Returns a fully-specified URL for websocket connections.
- (NSURL*) webSocketURLWithPath:(NSString*)path;

// Starts a GET request.
// Calls completionHandler with result dictionary.
- (void) startGetTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler;

// Starts a POST request with a given dictionary (will be serialized in JSON).
// Calls completionHandler with result dictionary.
-(void) startPostTaskWithURL:(NSURL *)url dictionary:(NSDictionary *)dict completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler;

// Starts a POST request with a given data.
// Calls completionHandler with result dictionary.
-(void) startPostTaskWithURL:(NSURL *)url data:(NSData *)data completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler;


// Starts a PUT request with a given dictionary (will be serialized in JSON).
// Calls completionHandler with result dictionary.
-(void) startPutTaskWithURL:(NSURL *)url dictionary:(NSDictionary *)dict completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler;

// Starts a PUT request with a given data.
// Calls completionHandler with result dictionary.
-(void) startPutTaskWithURL:(NSURL *)url data:(NSData *)data completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler;

@end
