//
//  SBNetworkActivityIndicator.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SBNetworkActivityIndicator : NSObject {
    NSInteger totalCount;
    NSMutableDictionary *identifierDictionnary;
}

+ (id)sharedInstance;

/*
 * Call beginActivity with instance identifier when starting a network activity
 */
- (void)beginActivity:(id)identifier;

/*
 * Call endActivity with instance identifier when network activity is finished
 */
- (void)endActivity:(id)identifier;

/*
 * Call removeActivity when ending a connection manager, it will automatically
 * remove the activity count related to this instance and will end indicator
 * if needed.
 */
- (void)removeActivity:(id)identifier;

@end
