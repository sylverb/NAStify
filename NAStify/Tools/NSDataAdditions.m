//
//  NSDataAdditions.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2013 CodeIsALie. All rights reserved.
//

#import "NSDataAdditions.h"

@implementation NSData (NSDataAdditions)
-(NSString*)hexRepresentationWithSpaces_AS:(BOOL)spaces
{
    const unsigned char* bytes = (const unsigned char*)[self bytes];
    NSUInteger nbBytes = [self length];
    //If spaces is true, insert a space every this many input bytes (twice this many output characters).
    static const NSUInteger spaceEveryThisManyBytes = 4UL;
    //If spaces is true, insert a line-break instead of a space every this many spaces.
    static const NSUInteger lineBreakEveryThisManySpaces = 4UL;
    const NSUInteger lineBreakEveryThisManyBytes = spaceEveryThisManyBytes * lineBreakEveryThisManySpaces;
    NSUInteger strLen = 2*nbBytes + (spaces ? nbBytes/spaceEveryThisManyBytes : 0);
    
    NSMutableString* hex = [[NSMutableString alloc] initWithCapacity:strLen];
    for(NSUInteger i=0; i<nbBytes; ) {
        [hex appendFormat:@"%02x", bytes[i]];
        //We need to increment here so that the every-n-bytes computations are right.
        ++i;
        
        if (spaces) {
            if (i % lineBreakEveryThisManyBytes == 0) [hex appendString:@"\n"];
            else if (i % spaceEveryThisManyBytes == 0) [hex appendString:@" "];
        }
    }
    return hex;
}

static const char _base32Alphabet[32] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
static const char _base32Padding[1] = "=";

+ (id)dataWithBase32String:(NSString *)base32String {
    if (([base32String length] % 8) != 0) return nil;

    NSMutableCharacterSet *base32CharacterSet = [[NSMutableCharacterSet alloc] init];
    [base32CharacterSet addCharactersInString:[[NSString alloc] initWithBytes:_base32Alphabet length:32 encoding:NSASCIIStringEncoding]];
    [base32CharacterSet addCharactersInString:[[NSString alloc] initWithBytes:_base32Padding length:1 encoding:NSASCIIStringEncoding]];
    if ([[base32String stringByTrimmingCharactersInSet:base32CharacterSet] length] != 0) return nil;

    NSUInteger paddingCharacters = 0; // 6, 4, 3, 1, 0 are allowed
    NSRange paddingRange = NSMakeRange(NSNotFound, 0);
    do {
        paddingRange = [base32String rangeOfString:@"=" options:(NSAnchoredSearch | NSBackwardsSearch) range:NSMakeRange(0, ([base32String length] - paddingCharacters))];
        if (paddingRange.location != NSNotFound) paddingCharacters++;
    } while (paddingRange.location != NSNotFound);
    if (paddingCharacters > 6 || (paddingCharacters == 5 || paddingCharacters == 2)) return nil;
    if ([base32String rangeOfString:@"=" options:(NSStringCompareOptions)0 range:NSMakeRange(0, ([base32String length] - paddingCharacters))].location != NSNotFound) return nil;


    NSMutableData *data = [NSMutableData dataWithCapacity:(([base32String length] / 8) * 5)];

    NSString *base32Alphabet = [[NSString alloc] initWithBytes:_base32Alphabet length:32 encoding:NSASCIIStringEncoding];
    CFRetain((__bridge CFTypeRef)(base32String));

    NSUInteger characterOffset = 0;
    while (characterOffset < [base32String length]) {
        uint8_t values[8] = {0};
        for (NSUInteger valueIndex = 0; valueIndex < 8; valueIndex++) {
            unichar currentCharacter = [base32String characterAtIndex:(characterOffset + valueIndex)];
            if (currentCharacter == _base32Padding[0]) {
                // Note: each value is a 5 bit quantity, UINT8_MAX is outside that range
                values[valueIndex] = UINT8_MAX;
                continue;
            }

            values[valueIndex] = (uint8_t)[base32Alphabet rangeOfString:[NSString stringWithFormat:@"%C", currentCharacter]].location;
        }

        // Note: there will always be at least two non-padding characters

        NSUInteger byteCount = 0;
        uint8_t bytes[5] = {0};

        do {
            // Note: first byte
            {
                bytes[0] = bytes[0] | ((values[0] & /* 0b11111 */ 31) << 3);
                bytes[0] = bytes[0] | ((values[1] & /* 0b11100 */ 28) >> 2);
            }
            byteCount++;

            // Note: second byte
            if (values[2] == UINT8_MAX) break;
            {
                bytes[1] = bytes[1] | ((values[1] & /* 0b00011 */ 3)  << 6);
                bytes[1] = bytes[1] | ((values[2] & /* 0b11111 */ 31) << 1);
                bytes[1] = bytes[1] | ((values[3] & /* 0b10000 */ 16) >> 4);
            }
            byteCount++;

            // Note: third byte
            if (values[4] == UINT8_MAX) break;
            {
                bytes[2] = bytes[2] | ((values[3] & /* 0b01111 */ 15) << 4);
                bytes[2] = bytes[2] | ((values[4] & /* 0b11110 */ 30) >> 1);
            }
            byteCount++;

            // Note: fourth byte
            if (values[5] == UINT8_MAX) break;
            {
                bytes[3] = bytes[3] | ((values[4] & /* 0b00001 */ 1)  << 7);
                bytes[3] = bytes[3] | ((values[5] & /* 0b11111 */ 31) << 2);
                bytes[3] = bytes[3] | ((values[6] & /* 0b11000 */ 24) >> 3);
            }
            byteCount++;

            // Note: fifth byte
            if (values[7] == UINT8_MAX) break;
            {
                bytes[4] = bytes[4] | ((values[6] & /* 0b00111 */ 7)  << 5);
                bytes[4] = bytes[4] | ((values[7] & /* 0b11111 */ 31) << 0);
            }
            byteCount++;
        } while (NO);

        [data appendBytes:bytes length:byteCount];
        characterOffset += 8;
    }
    
    CFRelease((__bridge CFTypeRef)(base32String));
    
    return data;
}

@end