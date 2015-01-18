//
//  SKProduct+priceAsString.m
//  NAStify
//
//  Created by Sylver Bruneau on 02/01/2015.
//  Copyright (c) 2015 CodeIsALie. All rights reserved.
//

#import "SKProduct+priceAsString.h"

@implementation SKProduct (priceAsString)

- (NSString *) priceAsString
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [formatter setLocale:[self priceLocale]];
    
    NSString *str = nil;
    if ([[self price] isEqualToNumber:[NSNumber numberWithFloat:0]])
    {
        str = NSLocalizedString(@"Free", nil);
    }
    else
    {
        str = [formatter stringFromNumber:[self price]];
    }
    return str;
}

@end