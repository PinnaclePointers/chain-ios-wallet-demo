//
//   Copyright 2012 Square Inc.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

#import <Foundation/Foundation.h>
#import <Security/SecCertificate.h>

typedef enum {
    ChainSR_CONNECTING   = 0,
    ChainSR_OPEN         = 1,
    ChainSR_CLOSING      = 2,
    ChainSR_CLOSED       = 3,
} ChainSRReadyState;

typedef enum ChainSRStatusCode : NSInteger {
    ChainSRStatusCodeNormal = 1000,
    ChainSRStatusCodeGoingAway = 1001,
    ChainSRStatusCodeProtocolError = 1002,
    ChainSRStatusCodeUnhandledType = 1003,
    // 1004 reserved.
    ChainSRStatusNoStatusReceived = 1005,
    // 1004-1006 reserved.
    ChainSRStatusCodeInvalidUTF8 = 1007,
    ChainSRStatusCodePolicyViolated = 1008,
    ChainSRStatusCodeMessageTooBig = 1009,
} ChainSRStatusCode;

@class ChainSRWebSocket;

extern NSString *const ChainSRWebSocketErrorDomain;
extern NSString *const ChainSRHTTPResponseErrorKey;

#pragma mark - SRWebSocketDelegate

@protocol ChainSRWebSocketDelegate;

#pragma mark - SRWebSocket

@interface ChainSRWebSocket : NSObject <NSStreamDelegate>

@property (nonatomic, weak) id <ChainSRWebSocketDelegate> delegate;

@property (nonatomic, readonly) ChainSRReadyState readyState;
@property (nonatomic, readonly, retain) NSURL *url;

// This returns the negotiated protocol.
// It will be nil until after the handshake completes.
@property (nonatomic, readonly, copy) NSString *protocol;

// Protocols should be an array of strings that turn into Sec-WebSocket-Protocol.
- (id)initWithURLRequest:(NSURLRequest *)request protocols:(NSArray *)protocols;
- (id)initWithURLRequest:(NSURLRequest *)request;

// Some helper constructors.
- (id)initWithURL:(NSURL *)url protocols:(NSArray *)protocols;
- (id)initWithURL:(NSURL *)url;

// Delegate queue will be dispatch_main_queue by default.
// You cannot set both OperationQueue and dispatch_queue.
- (void)setDelegateOperationQueue:(NSOperationQueue*) queue;
- (void)setDelegateDispatchQueue:(dispatch_queue_t) queue;

// By default, it will schedule itself on +[NSRunLoop SR_networkRunLoop] using defaultModes.
- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;
- (void)unscheduleFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode;

// SRWebSockets are intended for one-time-use only.  Open should be called once and only once.
- (void)open;

- (void)close;
- (void)closeWithCode:(NSInteger)code reason:(NSString *)reason;

// Send a UTF8 String or Data.
- (void)send:(id)data;

// Send Data (can be nil) in a ping message.
- (void)sendPing:(NSData *)data;

@end

#pragma mark - ChainSRWebSocketDelegate

@protocol ChainSRWebSocketDelegate <NSObject>

// message will either be an NSString if the server is using text
// or NSData if the server is using binary.
- (void)webSocket:(ChainSRWebSocket *)webSocket didReceiveMessage:(id)message;

@optional

- (void)webSocketDidOpen:(ChainSRWebSocket *)webSocket;
- (void)webSocket:(ChainSRWebSocket *)webSocket didFailWithError:(NSError *)error;
- (void)webSocket:(ChainSRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
- (void)webSocket:(ChainSRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload;

@end

#pragma mark - NSURLRequest (XCCertificateAdditions)

@interface NSURLRequest (XCCertificateAdditions)

@property (nonatomic, retain, readonly) NSArray *ChainSR_SSLPinnedCertificates;

// Unlike pinned certificates, anchors allow arbitrary certificates validation,
// but only against the given anchors.
// Should be an array of SecCertificateRef objects.
@property (nonatomic, retain, readonly) NSArray *ChainSR_SSLAnchorCertificates;

@end

#pragma mark - NSMutableURLRequest (XCCertificateAdditions)

@interface NSMutableURLRequest (XCCertificateAdditions)

@property (nonatomic, retain) NSArray *ChainSR_SSLPinnedCertificates;

// Unlike pinned certificates, anchors allow arbitrary certificates validation,
// but only against the given anchors.
// Should be an array of SecCertificateRef objects.
@property (nonatomic, retain) NSArray *ChainSR_SSLAnchorCertificates;

@end

#pragma mark - NSRunLoop (ChainSRWebSocket)

@interface NSRunLoop (ChainSRWebSocket)

+ (NSRunLoop *)ChainSR_networkRunLoop;

@end
