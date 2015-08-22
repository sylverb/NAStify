//
//  GetSeedResponseSerializer.m
//  PydioSDK
//
//  Created by Michal Kloczko on 01/03/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "GetSeedResponseSerializer.h"
#import "GetSeedTextResponseSerializer.h"
#import "GetSeedJSONResponseSerializer.h"


@interface GetSeedResponseSerializer ()
@property (readwrite, nonatomic, strong) NSArray *responseSerializers;
@end

@implementation GetSeedResponseSerializer

-(instancetype)init {
    self = [super init];
    if (self) {
        self.responseSerializers = @[
                                     [GetSeedJSONResponseSerializer serializer],
                                     [GetSeedTextResponseSerializer serializer]
                                     ];
    }
    
    return self;
}

@end
