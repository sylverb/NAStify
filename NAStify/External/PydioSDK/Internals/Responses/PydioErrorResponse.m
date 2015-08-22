//
//  PydioErrorResponse.m
//  PydioSDK
//
//  Created by ME on 17/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "PydioErrorResponse.h"

@implementation PydioErrorResponse

+(instancetype)errorResponseWithString:(NSString*)message {
    return [[[self class] alloc] initWithString:message];
}

-(instancetype)initWithString:(NSString*)message {
    self = [super init];
    if (self) {
        _message = [NSString stringWithString:message];
    }
    
    return self;
}

-(BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[self class]]) {
        return NO;
    }
    
    if (self.message != [object message] && ![self.message isEqualToString:[object message]]) {
        return NO;
    }
    
    return YES;
}

-(NSUInteger)hash {
    return [self.message hash];
}

@end
