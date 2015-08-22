//
//  LoginResponse.h
//  PydioSDK
//
//  Created by ME on 05/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, LRValue) {
    LRValueOK,
    LRValueFail,
    LRValueLocked,
    LRValueUnknown
};

@interface LoginResponse : NSObject
-(instancetype)initWithValue:(NSString*)value AndToken:(NSString*)token;

@property (readonly,nonatomic,assign) LRValue value;
@property (readonly,nonatomic,strong) NSString *secureToken;
@end
