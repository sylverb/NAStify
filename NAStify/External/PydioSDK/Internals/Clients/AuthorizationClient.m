//
//  AuthorizationClient.m
//  PydioSDK
//
//  Created by ME on 06/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "AuthorizationClient.h"
#import "AFHTTPRequestOperationManager.h"
#import "GetSeedResponseSerializer.h"
#import "ServersParamsManager.h"
#import "NSString+Hash.h"
#import "User.h"
#import "LoginResponse.h"
#import "SeedResponse.h"
#import "PydioErrors.h"
#import "XMLResponseSerializer.h"
#import "XMLResponseSerializerDelegate.h"
#import "GetCaptchaResponseSerializer.h"


typedef void(^AFSuccessBlock)(AFHTTPRequestOperation *operation, id responseObject);
typedef void(^AFFailureBlock)(AFHTTPRequestOperation *operation, NSError *error);

static NSString * const PING_ACTION = @"index.php?get_action=ping";
static NSString * const GET_SEED_ACTION = @"index.php?get_action=get_seed";
static NSString * const GET_ACTION = @"get_action";
static NSString * const USERID = @"userid";
static NSString * const PASSWORD = @"password";
static NSString * const LOGIN_SEED = @"login_seed";
static NSString * const CAPTCHA_CODE = @"captcha_code";


@interface AuthorizationClient ()
@property (readwrite,nonatomic,assign) BOOL progress;
@property (nonatomic,copy) AFSuccessBlock afSuccessBlock;
@property (nonatomic,copy) AFFailureBlock afFailureBlock;
@property (nonatomic,copy) SuccessBlock successBlock;
@property (nonatomic,copy) FailureBlock failureBlock;

-(void)clearBlocks;
-(void)setupSuccess:(SuccessBlock)success AndFailure:(FailureBlock)failure;
-(void)setupSuccess:(SuccessBlock)success;
-(void)setupFailure:(FailureBlock)failure;
-(void)setupAFFailureBlock;
-(void)setupPingSuccessBlock;
-(void)setupSeedSuccessBlock;
-(void)setupLoginSuccessBlock;
-(void)ping;
-(void)getSeed;
-(void)login:(User*)user WithCaptcha:(NSString*)captcha;
-(void)login:(User*)user;
@end

@implementation AuthorizationClient

#pragma mark - Setup process

-(void)clearBlocks {
    self.failureBlock = nil;
    self.successBlock = nil;
    self.afSuccessBlock = nil;
    self.afFailureBlock = nil;
}

-(void)setupSuccess:(SuccessBlock)success AndFailure:(FailureBlock)failure {
    [self setupSuccess:success];
    [self setupFailure:failure];
}

-(void)startProgressAndSetupCommonBlocks:(SuccessBlock)success failure:(FailureBlock)failure {
    self.progress = YES;
    [self setupSuccess:success AndFailure:failure];
    [self setupAFFailureBlock];
}

-(void)setupSuccess:(SuccessBlock)success {
    __weak typeof(self) weakSelf = self;
    self.successBlock = ^(id response) {
        if (!weakSelf) {
            return;
        }
        __strong typeof(self) strongSelf = weakSelf;
        success(response);
        [strongSelf clearBlocks];
        strongSelf->_progress = NO;
    };
}

-(void)setupFailure:(FailureBlock)failure {
    __weak typeof(self) weakSelf = self;
    self.failureBlock = ^(NSError *error) {
        if (!weakSelf) {
            return;
        }
        __strong typeof(self) strongSelf = weakSelf;
        failure(error);
        [strongSelf clearBlocks];
        strongSelf->_progress = NO;
    };
}

-(void)setupGetCaptchaSuccess {
    __weak typeof(self) weakSelf = self;
    self.afSuccessBlock = ^(AFHTTPRequestOperation *operation, id response) {
        if (!weakSelf) {
            return;
        }
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.successBlock(response);
    };
}

-(void)setupAFFailureBlock {
    __weak typeof(self) weakSelf = self;
    self.afFailureBlock = ^(AFHTTPRequestOperation *operation,NSError *error){
        if (!weakSelf) {
            return;
        }
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.failureBlock(error);
    };
}

-(void)setupPingSuccessBlock {
    __weak typeof(self) weakSelf = self;
    self.afSuccessBlock = ^(AFHTTPRequestOperation *operation, id responseObject){
        if (!weakSelf) {
            return;
        }
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf setupSeedSuccessBlock];
        [strongSelf getSeed];
    };
}

-(void)setupSeedSuccessBlock {
    __weak typeof(self) weakSelf = self;
    self.afSuccessBlock = ^(AFHTTPRequestOperation *operation, SeedResponse *seed) {
        if (!weakSelf) {
            return;
        }
        __strong typeof(self) strongSelf = weakSelf;
        [[ServersParamsManager sharedManager] setSeed:seed.seed ForServer:strongSelf.operationManager.baseURL];
        if (!seed.captcha) {
            [strongSelf setupLoginSuccessBlock];
            User *user = [[ServersParamsManager sharedManager] userForServer:strongSelf.operationManager.baseURL];
            [strongSelf login:user];
        } else {
            NSError *error = [NSError errorWithDomain:PydioErrorDomain code:PydioErrorGetSeedWithCaptcha userInfo:nil];
            strongSelf.failureBlock(error);
        }
    };
}

-(void)setupLoginSuccessBlock {
    __weak typeof(self) weakSelf = self;
    self.afSuccessBlock = ^(AFHTTPRequestOperation *operation, LoginResponse *response) {
        if (!weakSelf) {
            return;
        }
        __strong typeof(self) strongSelf = weakSelf;
        if (response.value == LRValueOK) {
            [[ServersParamsManager sharedManager] setSecureToken:response.secureToken ForServer:strongSelf.operationManager.baseURL];
            strongSelf.successBlock(nil);
        } else if (response.value == LRValueLocked) {
            NSError *error = [NSError errorWithDomain:PydioErrorDomain code:PydioErrorLoginWithCaptcha userInfo:nil];
            strongSelf.failureBlock(error);
        } else {
            NSError *error = [NSError errorWithDomain:PydioErrorDomain code:PydioErrorUnableToLogin userInfo:nil];
            strongSelf.failureBlock(error);
        }
    };
    
}

#pragma mark - Authorization process

-(BOOL)authorizeWithSuccess:(SuccessBlock)success failure:(FailureBlock)failure {
    if (self.progress) {
        return NO;
    }
    
    [self startProgressAndSetupCommonBlocks:success failure:failure];
    [self setupPingSuccessBlock];
    
    [self ping];
    
    return YES;
}

-(BOOL)login:(NSString *)captcha WithSuccess:(SuccessBlock)success failure:(FailureBlock)failure {
    if (self.progress) {
        return NO;
    }
    
    [self startProgressAndSetupCommonBlocks:success failure:failure];
    [self setupLoginSuccessBlock];
    
    User *user = [[ServersParamsManager sharedManager] userForServer:self.operationManager.baseURL];
    [self login:user WithCaptcha:captcha];
    
    return YES;
}

-(BOOL)getCaptchaWithSuccess:(void(^)(NSData *captcha))success failure:(FailureBlock)failure {
    if (self.progress) {
        return NO;
    }
    
    [self startProgressAndSetupCommonBlocks:success failure:failure];
    [self setupGetCaptchaSuccess];
    self.operationManager.responseSerializer = [[GetCaptchaResponseSerializer alloc] init];
    
    [self getOperation:@"get_captcha"];
    
    return YES;
}

#pragma mark - Authorization steps

-(void)ping {
    [self getOperation:@"ping"];
}

-(void)getSeed {
    self.operationManager.responseSerializer =  [GetSeedResponseSerializer serializer];
    [self getOperation:@"get_seed"];
    
}

-(void)login:(User*)user WithCaptcha:(NSString*)captcha {
    [self.operationManager.requestSerializer setValue:@"true" forHTTPHeaderField:@"Ajxp-Force-Login"];
    self.operationManager.responseSerializer = [self createLoginResponseSerializer];
    NSString *seed = [[ServersParamsManager sharedManager] seedForServer:self.operationManager.baseURL];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjects:@[ @"login",
                                                                                user.userid,
                                                                                [self hashedPass:user.password WithSeed:seed],
                                                                                seed]
                                                                     forKeys:@[GET_ACTION,
                                                                               USERID,
                                                                               PASSWORD,
                                                                               LOGIN_SEED]];
    
    if (captcha) {
        [params setValue:captcha forKey:CAPTCHA_CODE];
    }
    
    [self.operationManager POST:@"" parameters:params success:self.afSuccessBlock failure:self.afFailureBlock];
}

-(void)login:(User*)user {
    [self login:user WithCaptcha:nil];
}

#pragma - Helpers

-(NSString *)hashedPass:(NSString*)pass WithSeed:(NSString *)seed {
    return [seed isEqualToString:@"-1"] ? pass : [[NSString stringWithFormat:@"%@%@", [pass md5], seed] md5];
}

-(XMLResponseSerializer*)createLoginResponseSerializer {
    LoginResponseSerializerDelegate *delegate = [[LoginResponseSerializerDelegate alloc] init];
    return [[XMLResponseSerializer alloc] initWithDelegate:delegate];
}

-(void)getOperation:(NSString *)operation {
    [self.operationManager GET:@"index.php" parameters:@{GET_ACTION : operation} success:self.afSuccessBlock failure:self.afFailureBlock];
}

@end
