//
//  NSString+Hash.m
//  PydioSDK
//
//  Created by ME on 04/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "NSString+Hash.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (Hash)

- (NSString *) md5 {
    const char *cStr = [self UTF8String];
    unsigned char result[16];
    CC_MD5( cStr, (CC_LONG)strlen(cStr), result ); // This is the md5 call
    NSMutableString *mutable = [NSMutableString string];
    for (int i=0; i<sizeof(result); ++i) {
        [mutable appendFormat:@"%02x",result[i]];
    }
    return [NSString stringWithString:mutable];
}

@end
