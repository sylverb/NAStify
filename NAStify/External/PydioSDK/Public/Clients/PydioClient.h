//
//  PydioClient.h
//  PydioSDK
//
//  Created by ME on 09/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Commons.h"

@class ListNodesRequestParams;
@class MkDirRequestParams;
@class DeleteNodesRequestParams;

typedef NS_ENUM(NSUInteger, PydioClientState) {
    PydioClientIdle,
    PydioClientOperation,
    PydioClientAuthorization,
    PydioClientFinished
};

typedef void(^StateChangeBlock)(PydioClientState newState);


@interface PydioClient : NSObject
@property (readonly,nonatomic,strong) NSURL* serverURL;
@property (readonly,nonatomic,assign) BOOL progress;
@property (readonly,nonatomic,assign) PydioClientState state;
@property (nonatomic,strong) StateChangeBlock stateChangeBlock;


-(instancetype)initWithServer:(NSString *)server;

-(BOOL)authorizeWithSuccess:(void(^)(id ignored))success failure:(FailureBlock)failure;
-(BOOL)login:(NSString *)captcha WithSuccess:(void(^)(id ignored))success failure:(FailureBlock)failure;
-(BOOL)getCaptchaWithSuccess:(void(^)(NSData *captcha))success failure:(FailureBlock)failure;
-(BOOL)listWorkspacesWithSuccess:(void(^)(NSArray* workspaces))success failure:(FailureBlock)failure;
-(BOOL)listNodes:(ListNodesRequestParams*)params WithSuccess:(void(^)(NSArray* nodes))success failure:(FailureBlock)failure;
-(BOOL)mkdir:(MkDirRequestParams*)params WithSuccess:(void(^)(id ignored))success failure:(FailureBlock)failure;
-(BOOL)deleteNodes:(DeleteNodesRequestParams*)params WithSuccess:(void(^)())success failure:(FailureBlock)failure;
@end
