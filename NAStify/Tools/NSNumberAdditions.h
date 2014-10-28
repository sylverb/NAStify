//
//  NSNumberAdditions.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSNumber (NSNumberAdditions)

/*
 * converts number of bytes into NSString
 */
- (NSString *)stringForNumberOfBytes;

/*
 * return information about write right of the users from posix permissions
 */
- (BOOL)userHasWriteAccessFromPosixPermissions;

@end
