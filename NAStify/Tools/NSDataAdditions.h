//
//  NSDataAdditions.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2013 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (NSDataAdditions)
/*
 * create an user agent string
 */
- (NSString *)hexRepresentationWithSpaces_AS:(BOOL)spaces;

/*
 * Decode a base32 string, this encoding is defined in IETF-RFC-4648 Â§6 http://tools.ietf.org/html/rfc4648#section-6
 * return nil if the <tt>base32String</tt> parameter is not a valid base32 encoding.
 */
+ (id)dataWithBase32String:(NSString *)base32String;

@end
