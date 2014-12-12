//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// Information about an OP_RETURN output.
@interface ChainOpReturn : NSObject

// The transaction hash where this OP_RETURN is found.
@property(nonatomic, readonly) NSData* transactionHash;

// The transaction ID (reversed hash in hex) where this OP_RETURN is found.
@property(nonatomic, readonly) NSString* transactionID;

// Binary data encoded in the OP_RETURN output.
@property(nonatomic, readonly) NSData* data;

// UTF-8 string decoded in the OP_RETURN output.
// Contains nil if the data is not a valid UTF-8 string.
@property(nonatomic, readonly) NSString* text;

// List of BTCAddresses associated with the inputs of the transaction.
@property(nonatomic, readonly) NSArray* senderAddresses;

// List of BTCAddresses associated with the outputs of the transaction.
@property(nonatomic, readonly) NSArray* receiverAddresses;

// Dictionary representation of the OP_RETURN info.
@property(nonatomic, readonly) NSDictionary* dictionary;

- (id) initWithDictionary:(NSDictionary*)dictionary;

@end
