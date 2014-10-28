//
//  NSStringAdditions.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (NSStringAdditions)

/*
 * create an user agent string
 */
+ (NSString *)defaultUserAgentString;

/*
 * Format string for size
 */
+ (NSString *) stringForSize:(long long)size;

/*
 * Generate an UUID
 */
+(NSString *)generateUUID;

- (NSString *)encodePathString:(NSStringEncoding)encoding;

/*
 * Encode string with % and escape for url
 */
- (NSString *)encodeString:(NSStringEncoding)encoding;

/*
 * Get string representation of hexa string (for Synology devices)
 */
- (NSString *)hexRepresentation;

/*
 * Get NSNumber for string containing size (xx MB / xx KB / ...) (for Synology devices)
 */
- (NSNumber *)valueForStringBytes;

/*
 * Get string with all leading white spaces removed
 */
- (NSString*)stringByTrimmingLeadingWhitespace;

/*
 * Encode a string (used for QNAP devices login process)
 */
- (NSString *)ezEncode;

/*
 * Get string without parameters (for URL type string)
 */
- (NSString *)stringWithoutParameters;

/*
 * Get string representation with " char escaped
 */
- (NSString *)stringWithSlash;

@end
