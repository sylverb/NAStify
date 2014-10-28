//
//  SBNetworkActivityIndicator.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "SBNetworkActivityIndicator.h"

@implementation SBNetworkActivityIndicator

+ (id)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        identifierDictionnary = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)beginActivity:(id)identifier
{
#ifndef APP_EXTENSION
    if (totalCount == 0)
    {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    }
    totalCount++;
    
    NSString *ident = [NSString stringWithFormat:@"%@",identifier];
    NSInteger countForIdentifier = [[identifierDictionnary objectForKey:ident] integerValue];
    countForIdentifier ++;
    [identifierDictionnary setObject:[NSNumber numberWithInteger:countForIdentifier] forKey:ident];
#endif
}

- (void)endActivity:(id)identifier
{
#ifndef APP_EXTENSION
    NSString *ident = [NSString stringWithFormat:@"%@",identifier];
    if ([identifierDictionnary objectForKey:ident])
    {
        NSInteger countForIdentifier = [[identifierDictionnary objectForKey:ident] integerValue];
        if (countForIdentifier == 0)
        {
            NSLog(@"Warning : endActivity => unbalanced start/end call for identifier %@",ident);
        }
        else
        {
            countForIdentifier --;
            [identifierDictionnary setObject:[NSNumber numberWithInteger:countForIdentifier] forKey:ident];
            
            if (totalCount == 0)
            {
                NSLog(@"Warning : endActivity => unbalanced start/end call");
            }
            else
            {
                totalCount--;
                if (totalCount == 0)
                {
                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                }
            }
        }
    }
#endif
}

- (void)removeActivity:(id)identifier
{
#ifndef APP_EXTENSION
    NSString *ident = [NSString stringWithFormat:@"%@",identifier];
    if ([identifierDictionnary objectForKey:ident])
    {
        NSInteger countForIdentifier = [[identifierDictionnary objectForKey:ident] integerValue];
        if (totalCount >= countForIdentifier)
        {
            totalCount -= countForIdentifier;
            if (totalCount == 0)
            {
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
            }
        }
        else
        {
            NSLog(@"Warning : removeActivity => unbalanced start/end call");
        }
        [identifierDictionnary removeObjectForKey:ident];
    }
#endif
}

@end
