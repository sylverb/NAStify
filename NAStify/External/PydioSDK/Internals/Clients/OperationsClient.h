//
//  OperationsClient.h
//  PydioSDK
//
//  Created by ME on 14/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Commons.h"

@class AFHTTPRequestOperationManager;

@interface OperationsClient : NSObject
@property (nonatomic,strong) AFHTTPRequestOperationManager *operationManager;
@property (readonly,nonatomic,assign) BOOL progress;

-(BOOL)listWorkspacesWithSuccess:(void(^)(NSArray *workspaces))success failure:(FailureBlock)failure;
-(BOOL)listFiles:(NSDictionary*)params WithSuccess:(void(^)(NSArray* files))success failure:(FailureBlock)failure;
-(BOOL)mkdir:(NSDictionary*)params WithSuccess:(void(^)(NSArray* files))success failure:(FailureBlock)failure;
-(BOOL)deleteNodes:(NSDictionary*)params WithSuccess:(void(^)())success failure:(FailureBlock)failure;
@end
