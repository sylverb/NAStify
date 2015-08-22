//
//  GetSeedJSONResponseSerializer.m
//  PydioSDK
//
//  Created by Michal Kloczko on 01/03/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "GetSeedJSONResponseSerializer.h"
#import "SeedResponse.h"


@implementation GetSeedJSONResponseSerializer

#pragma mark - AFURLRequestSerialization

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    id responseObject = [super responseObjectForResponse:response data:data error:error];
    SeedResponse *result = nil;
    if (responseObject && [responseObject isKindOfClass:[NSDictionary class]]) {
        NSString *seed = [responseObject valueForKey:@"seed"];
        NSNumber *captcha = [responseObject valueForKey:@"captcha"];
        
        if (seed && captcha && [captcha boolValue]) {
            result = [SeedResponse seedWithCaptcha:seed];
        }
    }
    
    return result;
}

@end
