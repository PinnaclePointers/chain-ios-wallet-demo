//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#import "Chain.h"
#import "ChainConnection.h"
#import <CoreBitcoin/CoreBitcoin.h>

typedef NS_ENUM(NSUInteger, ChainRequestMethod) {
    ChainRequestMethodGet,
    ChainRequestMethodPost,
    ChainRequestMethodPut,
};

@interface ChainConnection () <NSURLSessionDelegate>
@property(nonatomic) NSURLSession* session;
@property(nonatomic, readwrite) NSArray* anchorCertificates;
@end

@implementation ChainConnection


- (id) init {
    if (self = [super init]) {
        NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfiguration.HTTPAdditionalHeaders = @{
          @"Accept":          @"application/json",
          @"Accept-Language": @"en"
        };
        self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];

        // In Test target mainBundle does not correspond to the bundle where certificate is stored.
        // To access it we need to ask for a bundle from which this class was loaded.
        // Cf. http://stackoverflow.com/questions/16310660/how-to-add-open-a-bundle-file-in-a-test-target

        NSMutableArray* anchors = [NSMutableArray array];
        for (NSString* filename in @[@"ChainCertificate", @"ChainWSSCertificate"]) {
            NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:filename ofType:@"der"];
            NSData *certificateData = [NSData dataWithContentsOfFile:path];
            if (!certificateData) {
                [NSException raise:@"ChainException" format:@"can't find %@.der to verify SSL connection", filename];
            }
            SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData);
            [anchors addObject:CFBridgingRelease(certificate)];
        }
        self.anchorCertificates = anchors;
    }
    return self;
}

- (NSString*) baseURLString {
    return [NSString stringWithFormat:@"https://%@", self.hostname];
}

- (NSURL*) URLWithPath:(NSString *)path {
    NSString *auth = [self authSuffixForPath:path];
    NSString *URLString = [NSString stringWithFormat:@"%@/%@/%@/%@%@", [self baseURLString], self.version, self.blockchain, path, auth];
    return [NSURL URLWithString:URLString];
}

// Returns a fully-specified URL for websocket connections.
- (NSURL*) webSocketURLWithPath:(NSString*)path {
    NSString *URLString = [NSString stringWithFormat:@"wss://%@/%@/%@", self.webSocketHostname, self.version, path];
    return [NSURL URLWithString:URLString];
}

- (NSString *) authSuffixForPath:(NSString *)path {
    if ([path rangeOfString:@"?"].location == NSNotFound) {
        return [NSString stringWithFormat:@"?api-key-id=%@", self.token];
    } else {
        return [NSString stringWithFormat:@"&api-key-id=%@", self.token];
    }
}

-(void) startGetTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler {
    [self startTaskWithMethod:ChainRequestMethodGet URL:url data:nil completionHandler:completionHandler];
}

-(void) startPostTaskWithURL:(NSURL *)url dictionary:(NSDictionary *)dict completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler {

    NSError *serializationError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&serializationError];
    if (data == nil) {
        completionHandler(nil, serializationError);
    } else {
        [self startPostTaskWithURL:url data:data completionHandler:completionHandler];
    }
}

-(void) startPostTaskWithURL:(NSURL *)url data:(NSData *)data completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler {
    [self startTaskWithMethod:ChainRequestMethodPost URL:url data:data completionHandler:completionHandler];
}

-(void) startPutTaskWithURL:(NSURL *)url dictionary:(NSDictionary *)dict completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler {

    NSError *serializationError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&serializationError];
    if (data == nil) {
        completionHandler(nil, serializationError);
    } else {
        [self startPutTaskWithURL:url data:data completionHandler:completionHandler];
    }
}

-(void) startPutTaskWithURL:(NSURL *)url data:(NSData *)data completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler {
    [self startTaskWithMethod:ChainRequestMethodPut URL:url data:data completionHandler:completionHandler];
}

-(void) startTaskWithMethod:(ChainRequestMethod)method URL:(NSURL *)url data:(NSData *)data completionHandler:(void (^)(NSDictionary *dictionary, NSError *error))completionHandler {

    NSParameterAssert(completionHandler != nil);

    void(^chainCompletionHandler)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (response == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(nil, error);
            });
        } else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSError *parseError = nil;

            // Parse JSON on NSURLSession's background queue to not hurt the main thread.
            id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            NSDictionary *jsonDictionary = nil;
            if ([jsonObject isKindOfClass:[NSDictionary class]]) {
                jsonDictionary = jsonObject;
            } else if ([jsonObject isKindOfClass:[NSArray class]]) {
                jsonDictionary = @{@"results": jsonObject};
            }

            if (jsonDictionary == nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(nil, parseError);
                });
            } else {
                if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionHandler(jsonDictionary, nil);
                    });
                } else {
                    NSError *returnError = [self parseChainError:jsonDictionary];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completionHandler(nil, returnError);
                    });
                }
            }
        }
    };

    switch (method) {
        case ChainRequestMethodGet:
            {
                [[self.session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    chainCompletionHandler(data, response, error);
                }] resume];
            }
            break;
        case ChainRequestMethodPost:
            {
                NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
                [urlRequest setHTTPMethod:@"POST"];
                [[self.session uploadTaskWithRequest:urlRequest fromData:data completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    chainCompletionHandler(data, response, error);
                }] resume];
            }
            break;
        case ChainRequestMethodPut:
            {
                NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
                [urlRequest setHTTPMethod:@"PUT"];
                [[self.session uploadTaskWithRequest:urlRequest fromData:data completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    chainCompletionHandler(data, response, error);
                }] resume];
            }
            break;
        default:
            [NSException raise:@"ChainException" format:@"Unsupported request method"];
            break;
    }
}

- (NSError*) parseChainError:(NSDictionary*)dictionary {

    NSString* message = dictionary[@"message"] ?: dictionary[@"code"] ?: @"No Message";
    NSString* codeString = dictionary[@"code"] ?: @"CH000";

    NSInteger code = 0;
    if ([codeString rangeOfString:@"CH"].location == 0)
    {
        code = [[codeString substringFromIndex:2] integerValue];
    }

    return [NSError errorWithDomain:ChainErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message }];
}



#pragma mark - NSURLSessionDelegate


- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    SecTrustRef trust = challenge.protectionSpace.serverTrust;

    SecTrustSetAnchorCertificates(trust, (__bridge CFArrayRef)self.anchorCertificates);
    SecTrustSetAnchorCertificatesOnly(trust, true);

    SecTrustResultType result;
    OSStatus status = SecTrustEvaluate(trust, &result);
    NSURLCredential *credential = [NSURLCredential credentialForTrust:trust];

    if (status == errSecSuccess && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, credential);
    }
}


@end
