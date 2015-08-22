//
//  FailingResponseSerializer.m
//  PydioSDK
//
//  Created by ME on 06/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "FailingResponseSerializer.h"
#import "PydioErrors.h"


@implementation FailingResponseSerializer

- (BOOL)validateResponse:(NSHTTPURLResponse *)response
                    data:(NSData *)data
                   error:(NSError *__autoreleasing *)error
{
    NSDictionary *userInfo = @{
                               NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"Received not expected answer: %@", @"PydioSDK", nil), [response MIMEType]],
                               NSURLErrorFailingURLErrorKey:[response URL]
                              };
    if (error) {
        *error = [[NSError alloc] initWithDomain:PydioErrorDomain code:PydioErrorReceivedNotExpectedAnswer userInfo:userInfo];
    }
    
    return NO;
}

@end
