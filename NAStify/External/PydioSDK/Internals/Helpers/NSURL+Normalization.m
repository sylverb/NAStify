//
//  NSURL+Normalization.m
//  PydioSDK
//
//  Created by ME on 04/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "NSURL+Normalization.h"

@implementation NSURL (Normalization)

-(NSURL*)normalized {
    NSURL *url = self;
    if (![[url absoluteString] hasSuffix:@"/"]) {
        url = [url URLByAppendingPathComponent:@""];
    }
    
    return url;
}

@end
