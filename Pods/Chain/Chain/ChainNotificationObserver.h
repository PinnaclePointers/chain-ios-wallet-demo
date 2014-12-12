//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ChainConnection;
@class ChainNotification;
@class ChainNotificationResult;

// This represents an ephemeral connection to a websocket.
// Notifications are streamed in real time for as long as
// the TCP/IP connection stays alive.
@interface ChainNotificationObserver : NSObject

// Notifications being observed.
@property(nonatomic, readonly) NSArray* /* [ChainNotification] */ notifications;

// Block which is called on each notification result.
@property(nonatomic, strong) void(^resultHandler)(ChainNotificationResult* result);

// Block which is called when connection is lost or closed.
// Not called if you disconnect manually.
// You may choose to immediately reconnect (see `connect`). If you don't,
// all callback blocks will be cleared and this object will be invalidated.
@property(nonatomic, strong) void(^disconnectHandler)(BOOL succeeded, NSError* error);

- (id) initWithNotification:(ChainNotification*)notification connection:(ChainConnection*)connection;

- (id) initWithNotifications:(NSArray*)notifications connection:(ChainConnection*)connection;

// Connects if is not connected yet.
// The observer is automatically connected once returned from `Chain` instance,
// but you may call this to re-connect in `onDisconnect` block.
- (void) connect;

// Disconnects the observer, cleans the callbacks and invalidates it.
- (void) disconnect;

@end
