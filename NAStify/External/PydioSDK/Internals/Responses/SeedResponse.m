//
//  SeedResponse.m
//  PydioSDK
//
//  Created by Michal Kloczko on 01/03/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "SeedResponse.h"

@interface SeedResponse ()
@property (readwrite,nonatomic,strong) NSString *seed;
@property (readwrite,nonatomic,assign) BOOL captcha;

@end

@implementation SeedResponse

+(SeedResponse*)seedWithCaptcha:(NSString*)seed {
    return [[SeedResponse alloc] initWithCaptcha:seed];
}

+(SeedResponse*)seed:(NSString*)seed {
    return [[SeedResponse alloc] init:seed];
}

-(instancetype)init:(NSString*)seed {
    self = [super init];
    if (self) {
        self.seed = seed;
    }
    
    return self;
}

-(instancetype)initWithCaptcha:(NSString*)seed {
    self = [super init];
    if (self) {
        self.seed = seed;
        self.captcha = YES;
    }
    
    return self;
}

-(BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    
    if (![object isKindOfClass:[SeedResponse class]]) {
        return NO;
    }
    
    SeedResponse *converted = (SeedResponse*)object;
    
    if (self.captcha != [converted captcha]) {
        return NO;
    }
    
    if (self.seed != converted.seed && ![self.seed isEqualToString:converted.seed]) {
        return NO;
    }
    
    return YES;
}

-(NSUInteger)hash {
    NSUInteger prime = 31;
    NSUInteger result = 1;
    
    result = prime * result + (self.captcha)?1231:1237;
    result = prime * result + [self.seed hash];
    
    return result;
}

@end
