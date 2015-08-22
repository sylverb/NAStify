//
//  PydioClient.m
//  PydioSDK
//
//  Created by ME on 09/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "PydioClient.h"
#import "AFHTTPRequestOperationManager.h"
#import "ServersParamsManager.h"
#import "AuthorizationClient.h"
#import "OperationsClient.h"
#import "User.h"
#import "PydioErrors.h"
#import "ListNodesRequestParams.h"
#import "MkDirRequestParams.h"
#import "DeleteNodesRequestParams.h"


static const int AUTHORIZATION_TRIES_COUNT = 1;

@interface PydioClient ()
@property (nonatomic,strong) AFHTTPRequestOperationManager* operationManager;
@property (nonatomic,strong) AuthorizationClient* authorizationClient;
@property (nonatomic,strong) OperationsClient* operationsClient;
@property (nonatomic,copy) void(^operationBlock)();
@property (nonatomic,copy) void(^successBlock)(id response);
@property (nonatomic,copy) FailureBlock failureBlock;
@property (nonatomic,copy) void(^successResponseBlock)(id responseObject);
@property (nonatomic,copy) FailureBlock failureResponseBlock;
@property (nonatomic,assign) int authorizationsTriesCount;
@property (readwrite,nonatomic,assign) PydioClientState state;

-(AFHTTPRequestOperationManager*)createOperationManager:(NSString*)server;
-(AuthorizationClient*)createAuthorizationClient;
-(OperationsClient*)createOperationsClient;
-(void)setupResponseBlocks;
-(void)setupSuccessResponseBlock;
-(void)setupFailureResponseBlock;
-(void)setupCommons:(void(^)(id result))success failure:(FailureBlock)failure;
@end


@implementation PydioClient

-(NSURL*)serverURL {
    return self.operationManager.baseURL;
}

-(BOOL)progress {
    return self.authorizationClient.progress || self.operationsClient.progress;
}

-(void)setState:(PydioClientState)state {
    _state = state;
    if (self.stateChangeBlock) {
        self.stateChangeBlock(state);
    }
}

-(void)setOperationBlock:(void (^)())operationBlock {
    [self setOperationBlock:operationBlock WithState:PydioClientOperation];
}

-(void)setOperationBlockWithAuthorization:(void (^)())operationBlock {
    [self setOperationBlock:operationBlock WithState:PydioClientAuthorization];
}

-(void)setOperationBlock:(void (^)())operationBlock WithState:(PydioClientState)state {
    if (operationBlock == nil) {
        _operationBlock = nil;
    } else {
        __weak typeof(self) weakSelf = self;
        _operationBlock = ^{
            if (!weakSelf) {
                return;
            }
            __strong typeof(self) strongSelf = weakSelf;
            strongSelf.state = state;
            operationBlock();
        };
    }
}

#pragma mark - Initialization

-(instancetype)initWithServer:(NSString *)server {
    self = [super init];
    if (self) {
        self.operationManager = [self createOperationManager:server];
        self.operationsClient = [self createOperationsClient];
    }
    
    return self;
}

#pragma mark - Setup operations common parts

-(void)setupResponseBlocks {
    [self setupSuccessResponseBlock];
    [self setupFailureResponseBlock];
}

-(void)setupSuccessResponseBlock {
    __weak typeof(self) weakSelf = self;
    self.successResponseBlock = ^(id response){
        if (!weakSelf) {
            return;
        }
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.successBlock(response);
        strongSelf.state = PydioClientFinished;
        [strongSelf clearBlocks];
    };
}

-(void)setupFailureResponseBlock {
    __weak typeof(self) weakSelf = self;
    self.failureResponseBlock = ^(NSError *error){
        if (!weakSelf) {
            return;
        }
        __strong typeof(self) strongSelf = weakSelf;
        if ([strongSelf isAuthorizationError:error] && strongSelf.authorizationsTriesCount > 0) {
            strongSelf.authorizationsTriesCount--;
            [strongSelf setupAuthorizationClient];
            strongSelf.state = PydioClientAuthorization;
            [strongSelf.authorizationClient authorizeWithSuccess:strongSelf.operationBlock failure:strongSelf.failureResponseBlock];
        } else {
            strongSelf.failureBlock(error);
            strongSelf.state = PydioClientFinished;
            [strongSelf clearBlocks];
        }
    };
}

-(void)setupCommons:(void(^)(id result))success failure:(FailureBlock)failure {
    [self resetAuthorizationTriesCount];
    self.successBlock = success;
    self.failureBlock = failure;
    [self setupResponseBlocks];
}

#pragma mark -

-(BOOL)authorizeWithSuccess:(void(^)(id ignored))success failure:(FailureBlock)failure {
    if (self.progress) {
        return NO;
    }
    [self setupCommons:success failure:failure];
    self.authorizationsTriesCount = 0;
    
    typeof(self) strongSelf = self;
    [self setOperationBlockWithAuthorization: ^{
        [strongSelf setupAuthorizationClient];
        [strongSelf.authorizationClient authorizeWithSuccess:strongSelf.successResponseBlock failure:strongSelf.failureResponseBlock];
    }];
    
    self.operationBlock();
    
    return YES;
}

-(BOOL)login:(NSString *)captcha WithSuccess:(void(^)(id ignored))success failure:(FailureBlock)failure {
    if (self.progress) {
        return NO;
    }
    [self setupCommons:success failure:failure];
    self.authorizationsTriesCount = 0;
    
    typeof(self) strongSelf = self;
    [self setOperationBlockWithAuthorization: ^{
        [strongSelf setupAuthorizationClient];
        [strongSelf.authorizationClient login:captcha WithSuccess:strongSelf.successResponseBlock failure:strongSelf.failureResponseBlock];
    }];
    
    self.operationBlock();
    
    return YES;
}

-(BOOL)getCaptchaWithSuccess:(void(^)(NSData *captcha))success failure:(FailureBlock)failure {
    if (self.progress) {
        return NO;
    }
    [self setupCommons:success failure:failure];
    self.authorizationsTriesCount = 0;
    
    typeof(self) strongSelf = self;
    self.operationBlock = ^{
        [strongSelf setupAuthorizationClient];
        [strongSelf.authorizationClient getCaptchaWithSuccess:strongSelf.successResponseBlock failure:strongSelf.failureResponseBlock];
    };
    
    self.operationBlock();
    
    return YES;
}

-(BOOL)listWorkspacesWithSuccess:(void(^)(NSArray* workspaces))success failure:(FailureBlock)failure {
    if (self.progress) {
        return NO;
    }
    [self setupCommons:success failure:failure];
    
    typeof(self) strongSelf = self;
    self.operationBlock = ^{
        [strongSelf.operationsClient listWorkspacesWithSuccess:strongSelf.successResponseBlock failure:strongSelf.failureResponseBlock];
    };
    
    self.operationBlock();
    
    return YES;
}

-(BOOL)listNodes:(ListNodesRequestParams *)params WithSuccess:(void(^)(NSArray* nodes))success failure:(FailureBlock)failure {
    if (self.progress) {
        return NO;
    }
    [self setupCommons:success failure:failure];
    
    typeof(self) strongSelf = self;
    self.operationBlock = ^{
        [strongSelf.operationsClient listFiles:[params dictionaryRepresentation] WithSuccess:strongSelf.successResponseBlock failure:strongSelf.failureResponseBlock];
    };
    
    self.operationBlock();
    
    return YES;
}

-(BOOL)mkdir:(MkDirRequestParams*)params WithSuccess:(void(^)(id ignored))success failure:(FailureBlock)failure {
    if (self.progress) {
        return NO;
    }
    [self setupCommons:success failure:failure];
    
    typeof(self) strongSelf = self;
    self.operationBlock = ^{
        [strongSelf.operationsClient mkdir:[params dictionaryRepresentation] WithSuccess:strongSelf.successResponseBlock failure:strongSelf.failureResponseBlock];
    };
    
    self.operationBlock();
    
    return YES;
}

-(BOOL)deleteNodes:(DeleteNodesRequestParams*)params WithSuccess:(void(^)())success failure:(FailureBlock)failure {
    if (self.progress) {
        return NO;
    }
    [self setupCommons:success failure:failure];
    
    typeof(self) strongSelf = self;
    self.operationBlock = ^{
        [strongSelf.operationsClient deleteNodes:[params dictionaryRepresentation] WithSuccess:strongSelf.successResponseBlock failure:strongSelf.failureResponseBlock];
    };
    
    self.operationBlock();
    
    return YES;
}

#pragma mark - Helper methods

-(void)clearBlocks {
    self.operationBlock = nil;
    self.successBlock = nil;
    self.failureBlock = nil;
    self.successResponseBlock = nil;
    self.failureResponseBlock = nil;
}

-(AFHTTPRequestOperationManager*)createOperationManager:(NSString*)server {
    return [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:server]];
}

-(void)setupAuthorizationClient {
    self.authorizationClient = [self createAuthorizationClient];
}

-(AuthorizationClient*)createAuthorizationClient {
    AuthorizationClient *client = [[AuthorizationClient alloc] init];
    client.operationManager = self.operationManager;
    
    return client;
}

-(OperationsClient*)createOperationsClient {
    OperationsClient *client = [[OperationsClient alloc] init];
    client.operationManager = self.operationManager;
    
    return client;
}

-(BOOL)isAuthorizationError:(NSError *)error {
    return [error.domain isEqualToString:PydioErrorDomain] && error.code == PydioErrorRequireAuthorization;
}

-(void)resetAuthorizationTriesCount {
    self.authorizationsTriesCount = AUTHORIZATION_TRIES_COUNT;
}

@end
