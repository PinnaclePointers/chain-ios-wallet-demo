//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "ChainConnection.h"
#import "ChainNotification.h"
#import "ChainNotificationResult.h"
#import "ChainNotificationObserver.h"

// We use ChainSRWebSocket until SocketRocket merges our pull-req
// #import <SocketRocket/SRWebSocket.h>

#import "ChainSRWebSocket.h"

@interface ChainNotificationObserver () <ChainSRWebSocketDelegate>
@property(nonatomic, readwrite) NSArray* notifications;
@property(nonatomic) ChainSRWebSocket* socket;
@property(nonatomic) ChainConnection* connection;
@end

@implementation ChainNotificationObserver {
    BOOL _invalid;
    BOOL _canConnect;
}

- (id) initWithNotification:(ChainNotification*)notification connection:(ChainConnection*)connection
{
    NSParameterAssert(notification);
    return [self initWithNotifications:@[ notification ] connection:connection];
}

- (id) initWithNotifications:(NSArray*)notifications connection:(ChainConnection*)connection
{
    NSParameterAssert(notifications);
    NSParameterAssert(connection);

    if (self = [super init])
    {
        self.notifications = notifications;
        self.connection = connection;
        _canConnect = YES;
    }
    return self;
}

- (void) dealloc
{
    [self cleanup];
}

- (void) connect
{
    if (_invalid)
    {
        @throw [NSException exceptionWithName:@"ChainNotificationObserver can not connect after being invalidated"
                                       reason:@"If you disconnect manually or do not reconnect in disconnectHandler, the observer becomes invalid." userInfo:nil];
        return;
    }

    if (_canConnect)
    {
        _canConnect = NO;

        self.socket.delegate = nil;
        [self.socket close];

        // "wss://ws.chain.com/v2/notifications"
        NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:[self.connection webSocketURLWithPath:@"notifications"]];
        req.ChainSR_SSLAnchorCertificates = self.connection.anchorCertificates;
        
        self.socket = [[ChainSRWebSocket alloc] initWithURLRequest:req];
        self.socket.delegate = self;

        [self.socket open];
    }
}

- (void) disconnect
{
    [self cleanup];
}

- (void) cleanup
{
    self.resultHandler = nil;
    self.disconnectHandler = nil;
    _invalid = YES;
    [self.socket close];
    self.socket.delegate = nil;
    self.socket = nil;
}


#pragma mark - SRWebSocketDelegate


// message will either be an NSString if the server is using text
// or NSData if the server is using binary.
- (void)webSocket:(ChainSRWebSocket *)socket didReceiveMessage:(id)message
{
    if (_invalid) return;

    NSData* data = [message isKindOfClass:[NSString class]] ? [message dataUsingEncoding:NSUTF8StringEncoding] : message;

    NSAssert([data isKindOfClass:[NSData class]], @"Message must be data");

    NSError *parseError = nil;
    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];

    if (dict == nil) {
        if (self.disconnectHandler) self.disconnectHandler(NO, parseError);
        [self cleanup];
        return;
    }

    ChainNotificationResult* result = [ChainNotificationResult notificationResultWithDictionary:dict];

    if (result) {
        if (self.resultHandler) self.resultHandler(result);
    } else {
        NSLog(@"ChainNotificationObserver: Skipping result: %@", dict);
    }
}

- (void)webSocketDidOpen:(ChainSRWebSocket *)socket
{
    if (_invalid) return;

    for (ChainNotification* notif in self.notifications)
    {
        NSDictionary* dict = [notif dictionary];
        NSError* jsonerror = nil;
        NSData* payload = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&jsonerror];

        if (!payload)
        {
            if (self.disconnectHandler) self.disconnectHandler(NO, jsonerror);
            [self cleanup];
            return;
        }

        [socket send:payload];
    }
}

- (void)webSocket:(ChainSRWebSocket *)socket didFailWithError:(NSError *)error
{
    if (_invalid) return;

    _canConnect = YES;

    if (self.disconnectHandler) self.disconnectHandler(NO, error);

    if (_canConnect)
    {
        _canConnect = NO;
        _invalid = YES;
    }
}

- (void)webSocket:(ChainSRWebSocket *)socket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    if (_invalid) return;

    _canConnect = YES;

    if (self.disconnectHandler) self.disconnectHandler(YES, nil);

    if (_canConnect)
    {
        _canConnect = NO;
        _invalid = YES;
    }
}

- (void)webSocket:(ChainSRWebSocket *)socket didReceivePong:(NSData *)pongPayload
{
    if (_invalid) return;
}

@end
