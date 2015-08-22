//
//  AuthorizationClient.h
//  PydioSDK
//
//  Created by ME on 06/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Commons.h"

extern NSString * const PydioErrorDomain;

@class AFHTTPRequestOperationManager;

@interface AuthorizationClient : NSObject
@property (nonatomic,strong) AFHTTPRequestOperationManager *operationManager;
@property (readonly,nonatomic,assign) BOOL progress;

-(BOOL)authorizeWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure;
-(BOOL)login:(NSString *)captcha WithSuccess:(SuccessBlock)success failure:(FailureBlock)failure;
-(BOOL)getCaptchaWithSuccess:(void(^)(NSData *captcha))success failure:(FailureBlock)failure;
@end
