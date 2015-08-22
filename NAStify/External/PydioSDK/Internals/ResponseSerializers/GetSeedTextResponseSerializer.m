//
//  RequestSeedResponseSerializer.m
//  PydioSDK
//
//  Created by ME on 04/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "GetSeedTextResponseSerializer.h"
#import "SeedResponse.h"

@implementation GetSeedTextResponseSerializer
-(instancetype)init {
    self = [super init];
    if (self) {
        self.acceptableContentTypes = [NSSet setWithObject:@"text/plain"];
    }
    
    return self;
}

#pragma mark - AFURLResponseSerialization

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    id responseObject = [super responseObjectForResponse:response data:data error:error];
    if (responseObject) {
        return [SeedResponse seed:[[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding]];;
    }
    
    return nil;
}

@end
