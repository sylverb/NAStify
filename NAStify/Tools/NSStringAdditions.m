//
//  NSStringAdditions.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "NSStringAdditions.h"

@implementation NSString (NSStringAdditions)

+ (NSString *)defaultUserAgentString {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    
    // Attempt to find a name for this application
    NSString *appName = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (!appName) {
        appName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
    }
    // If we couldn't find one, we'll give up (and ASIHTTPRequest will use the standard CFNetwork user agent)
    if (!appName) {
        return nil;
    }
    NSString *appVersion = nil;
    NSString *marketingVersionNumber = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *developmentVersionNumber = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
    if (marketingVersionNumber && developmentVersionNumber) {
        if ([marketingVersionNumber isEqualToString:developmentVersionNumber]) {
            appVersion = marketingVersionNumber;
        } else {
            appVersion = [NSString stringWithFormat:@"%@ rv:%@",marketingVersionNumber,developmentVersionNumber];
        }
    } else {
        appVersion = (marketingVersionNumber ? marketingVersionNumber : developmentVersionNumber);
    }
    
    
    NSString *deviceName;
    NSString *OSName;
    NSString *OSVersion;
    
    NSString *locale = [[NSLocale currentLocale] localeIdentifier];
    
#if TARGET_OS_IPHONE
    UIDevice *device = [UIDevice currentDevice];
    deviceName = [device model];
    OSName = [device systemName];
    OSVersion = [device systemVersion];
    
#else
    deviceName = @"Macintosh";
    OSName = @"Mac OS X";
    
    // From http://www.cocoadev.com/index.pl?DeterminingOSVersion
    // We won't bother to check for systems prior to 10.4, since ASIHTTPRequest only works on 10.5+
    OSErr err;
    SInt32 versionMajor, versionMinor, versionBugFix;
    err = Gestalt(gestaltSystemVersionMajor, &versionMajor);
    if (err != noErr) return nil;
    err = Gestalt(gestaltSystemVersionMinor, &versionMinor);
    if (err != noErr) return nil;
    err = Gestalt(gestaltSystemVersionBugFix, &versionBugFix);
    if (err != noErr) return nil;
    OSVersion = [NSString stringWithFormat:@"%u.%u.%u", versionMajor, versionMinor, versionBugFix];
    
#endif
    // Takes the form "My Application 1.0 (Macintosh; Mac OS X 10.5.7; en_GB)"
    return [NSString stringWithFormat:@"%@ %@ (%@; %@ %@; %@)", appName, appVersion, deviceName, OSName, OSVersion, locale];
}

+ (NSString *) stringForSize:(long long)size {
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

/*
 * Generate an UUID
 */
+(NSString *)generateUUID
{
    CFUUIDRef newUniqueId = CFUUIDCreate(kCFAllocatorDefault);
    NSString * uuidString = (__bridge_transfer NSString*)CFUUIDCreateString(kCFAllocatorDefault, newUniqueId);
    CFRelease(newUniqueId);
    
    return uuidString;
}

/*
 * Encode string for url
 */
- (NSString *)encodeStringUrl:(NSStringEncoding)encoding
{
    return (__bridge_transfer NSString *) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)self,
                                                                NULL, (__bridge CFStringRef)@":/.?&=;+!@$()~",
                                                                CFStringConvertNSStringEncodingToEncoding(encoding));
}

/*
 * Encode string for url but path parts (not "/" and ".")
 */
- (NSString *)encodePathString:(NSStringEncoding)encoding
{
    return (__bridge_transfer NSString *) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)self,
                                                                                  NULL, (__bridge CFStringRef)@":?&=;+!@$()~",
                                                                                  CFStringConvertNSStringEncodingToEncoding(encoding));
}

/*
 * Get string representation of hexa string (for Synology devices)
 */
- (NSString *)hexRepresentation {
	NSInteger i;
	NSString *outputString = [NSString string];
	NSInteger lenght = [self length];
	const char *characters = [self cStringUsingEncoding:NSUTF8StringEncoding];
	for (i=0;i<lenght;i++) {
		if (characters[i] != (characters[i] & 0xFF)) {
			lenght++;
		}
		if (characters[i] != 0x00)
			outputString = [outputString stringByAppendingFormat:@"%2X",(characters[i]&0xFF)];
	}
	
	return outputString;
}

/*
 * Get NSNumber for string containing size (xx MB / xx KB / ...) (for Synology devices)
 */
- (NSNumber *)valueForStringBytes
{
    NSNumber *value = nil;
    NSArray *components = [[self stringByTrimmingLeadingWhitespace] componentsSeparatedByString:@" "];
    if ([components count] == 2)
    {
        NSInteger multiplier = 0;
        NSString *unit = [components objectAtIndex:1];
        if ([unit isEqualToString:@"TB"])
        {
            multiplier = 1024 * 1024 * 1024 * 1024;
        }
        else if ([unit isEqualToString:@"GB"])
        {
            multiplier = 1024 * 1024 * 1024;
        }
        else if ([unit isEqualToString:@"MB"])
        {
            multiplier = 1024 * 1024;
        }
        else if ([unit isEqualToString:@"KB"])
        {
            multiplier = 1024;
        }
        else if (([unit isEqualToString:@"B"]) ||
                 ([unit isEqualToString:@"Bytes"]) ||
                 ([unit isEqualToString:@"Byte"]))
        {
            multiplier = 1;
        }
        
        value = [NSNumber numberWithLongLong:multiplier * [[components objectAtIndex:0] floatValue]];
    }
    return value;
}

- (NSString*)stringByTrimmingLeadingWhitespace
{
    NSInteger i = 0;
    
    while ((i < [self length])
           && [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[self characterAtIndex:i]])
    {
        i++;
    }
    return [self substringFromIndex:i];
}

/*
 * Encode a string (used for QNAP devices login process)
 */
- (NSString *)ezEncode
{
	NSInteger i, len;
	static NSString *ezEncodeChars = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	char c1, c2, c3;
	
	len = [self length];
	i = 0;
	NSString *out = @"";
	while(i < len)
	{
		c1 = [self characterAtIndex:i++] & 0xff;
		if(i == len)
		{
			out = [out stringByAppendingFormat:@"%c%c==",
				   [ezEncodeChars characterAtIndex:(c1 >> 2)],
				   [ezEncodeChars characterAtIndex:((c1 & 0x3) << 4)]];
			break;
		}
		c2 = [self characterAtIndex:i++];
		if(i == len)
		{
			out = [out stringByAppendingFormat:@"%c%c%c=",
				   [ezEncodeChars characterAtIndex:(c1 >> 2)],
				   [ezEncodeChars characterAtIndex:((c1 & 0x3)<< 4) | ((c2 & 0xF0) >> 4)],
				   [ezEncodeChars characterAtIndex:(c2 & 0xF) << 2]];
			break;
		}
		c3 = [self characterAtIndex:i++];
		out = [out stringByAppendingFormat:@"%c%c%c%c",
			   [ezEncodeChars characterAtIndex:(c1 >> 2)],
			   [ezEncodeChars characterAtIndex:((c1 & 0x3)<< 4) | ((c2 & 0xF0) >> 4)],
			   [ezEncodeChars characterAtIndex:((c2 & 0xF) << 2) | ((c3 & 0xC0) >> 6)],
			   [ezEncodeChars characterAtIndex:c3 & 0x3F]];
	}
	return out;
}

/*
 * Get string without parameters (for URL type string)
 */
- (NSString *)stringWithoutParameters
{
    NSString *outString;
    NSRange position = [self rangeOfString:@"?"];
    if (position.location != NSNotFound)
    {
        outString = [self substringToIndex:position.location];
    }
    else
    {
        outString = self;
    }
    return outString;
}

/*
 * Get string representation with " char escaped
 */
- (NSString *)stringWithSlash {
    NSMutableString *result = [self mutableCopy];
    [result replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:0 range:NSMakeRange(0, [result length])];
    return [result copy];
}

@end
