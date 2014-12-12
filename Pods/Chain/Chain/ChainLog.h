//
//  Chain.h
//
//  Copyright (c) 2014 Chain Inc. All rights reserved.
//

#ifndef Chain_ChainLog_h
#define Chain_ChainLog_h

    #ifdef DEBUG
        #define ChainLog(...)   NSLog(@"Chain: %@", [NSString stringWithFormat:__VA_ARGS__])
        #define ChainError(...) NSLog(@"Chain Error: %@", [NSString stringWithFormat:__VA_ARGS__])
    #else
        #define ChainLog(args...)
        #define ChainError(...) NSLog(@"Chain Error: %@", [NSString stringWithFormat:__VA_ARGS__])
    #endif

#endif
