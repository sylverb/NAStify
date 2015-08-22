//
//  GetCaptchaResponseSerializer.m
//  PydioSDK
//
//  Created by Michal Kloczko on 23/03/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "GetCaptchaResponseSerializer.h"

@implementation GetCaptchaResponseSerializer

-(instancetype)init {
    self = [super init];
    if (self) {
        self.acceptableContentTypes = [[NSSet alloc] initWithObjects:
                                       @"image/tiff", @"image/jpeg", @"image/gif", @"image/png",
                                       @"image/ico", @"image/x-icon", @"image/bmp", @"image/x-bmp",
                                       @"image/x-xbitmap", @"image/x-win-bitmap", nil
                                       ];
    }
    
    return self;
}

@end
