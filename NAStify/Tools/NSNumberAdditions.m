//
//  NSNumberAdditions.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "NSNumberAdditions.h"

@implementation NSNumber (NSNumberAdditions)

- (NSString *)stringForNumberOfBytes
{
    long long size = [self longLongValue];
    if (size < 1024)
    {
        if (size > 1)
            return [NSString stringWithFormat: @"%lld %@", size, NSLocalizedString(@"bytes", "File size - bytes")];
        else
            return [NSString stringWithFormat: @"%lld %@", size, NSLocalizedString(@"byte", "File size - byte")];
    }
    
    CGFloat convertedSize;
    NSString * unit;
    if (size < pow(1024, 2))
    {
        convertedSize = size / 1024.0;
        unit = NSLocalizedString(@"KB", "File size - kilobytes");
    }
    else if (size < pow(1024, 3))
    {
        convertedSize = size / powf(1024.0, 2);
        unit = NSLocalizedString(@"MB", "File size - megabytes");
    }
    else if (size < pow(1024, 4))
    {
        convertedSize = size / powf(1024.0, 3);
        unit = NSLocalizedString(@"GB", "File size - gigabytes");
    }
    else
    {
        convertedSize = size / powf(1024.0, 4);
        unit = NSLocalizedString(@"TB", "File size - terabytes");
    }
    
    //attempt to have minimum of 3 digits with at least 1 decimal
    return convertedSize < 10.0 ? [NSString localizedStringWithFormat: @"%.2f %@", convertedSize, unit]
    : [NSString localizedStringWithFormat: @"%.1f %@", convertedSize, unit];
}

- (BOOL)userHasWriteAccessFromPosixPermissions
{
    BOOL result = NO;
    
    NSUInteger perms = [self integerValue];
    
    // get POSIX permissions for owner.
    unsigned long thisPart = (perms >> 6) & 0x7;
    
    /* b0 (1) : x
     * b1 (2) : w
     * b2 (4) : r
     */
    
    if (thisPart & 2)
    {
        result = YES;
    }
    return result;
}

@end
