//
//  NetworkConnection.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "NetworkConnection.h"

@implementation NetworkConnection

- (id)init
{
    self = [super init];
    if (self)
    {
        self.urlType = URLTYPE_LOCAL;
        self.requestCookies = nil;
        self.requestHeaders = nil;
        self.postRequestParams = nil;
    }
    return self;
}

-(BOOL) isFileURL
{
    BOOL result = NO;
    switch (self.urlType)
    {
        case URLTYPE_LOCAL:
        {
            result = YES;
            break;
        }
        case URLTYPE_HTTP:
        {
            result = [self.url isFileURL];
            break;
        }
        case URLTYPE_HTTP_POST:
        {
            result = NO;
        }
        default:
            break;
    }
    return result;
}

@end
