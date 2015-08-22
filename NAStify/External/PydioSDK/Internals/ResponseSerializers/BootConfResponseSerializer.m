//
//  BootConfResponseSerializer.m
//  PydioSDK
//
//  Created by ME on 04/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "BootConfResponseSerializer.h"
#import "PydioErrors.h"

NSString * const PydioErrorDomain = @"PydioErrorDomain";

static NSString * const TOKEN=@"SECURE_TOKEN";

@implementation BootConfResponseSerializer

#pragma mark - AFURLRequestSerialization

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    id responseObject = [super responseObjectForResponse:response data:data error:error];
    if (!responseObject) {
        return nil;
    }

    NSDictionary *responseDictionary = nil;
    if ([responseObject isKindOfClass:[NSDictionary class]]) {
        responseDictionary = (NSDictionary*)responseObject;
    }
    
    NSString *token = nil;
    if (responseDictionary) {
        token = [responseObject valueForKey:TOKEN];
    }

    if (token) {
        return token;
    }
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error extracting %@", nil, @"PydioSDK"),TOKEN] forKey:NSLocalizedDescriptionKey];
    [userInfo setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Could not extract %@: %@", nil, @"PydioSDK"),TOKEN, responseObject] forKey:NSLocalizedFailureReasonErrorKey];
    if (error) {
        *error = [[NSError alloc] initWithDomain:PydioErrorDomain code:PydioErrorUnableToParseAnswer userInfo:userInfo];
    }

    return nil;
}

@end
