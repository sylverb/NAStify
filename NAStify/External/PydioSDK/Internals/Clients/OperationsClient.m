//
//  OperationsClient.m
//  PydioSDK
//
//  Created by ME on 14/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "OperationsClient.h"
#import "AFHTTPRequestOperationManager.h"
#import "ServersParamsManager.h"
#import "XMLResponseSerializer.h"
#import "XMLResponseSerializerDelegate.h"
#import "FailingResponseSerializer.h"
#import "NotAuthorizedResponse.h"
#import "PydioErrorResponse.h"
#import "PydioErrors.h"


extern NSString * const PydioErrorDomain;

#pragma mark -

@interface AggregatedArgs : NSObject
@property (nonatomic,copy) SuccessBlock success;
@property (nonatomic,copy) FailureBlock failure;

+(AggregatedArgs*) argsWith:(SuccessBlock)success failure:(FailureBlock)failure;
@end

@implementation AggregatedArgs

+(AggregatedArgs*) argsWith:(SuccessBlock)success failure:(FailureBlock)failure {
    AggregatedArgs *args = [[AggregatedArgs alloc] init];
    args.success = success;
    args.failure = failure;
    
    return args;
}

@end

#pragma mark - Implementation started

@interface OperationsClient ()
@property (readwrite,nonatomic,assign) BOOL progress;
@property (nonatomic,copy) SuccessBlock successBlock;
@property (nonatomic,copy) FailureBlock failureBlock;
@property (nonatomic,copy) void(^successResponseBlock)(AFHTTPRequestOperation *operation, id responseObject);
@property (nonatomic,copy) void(^failureResponseBlock)(AFHTTPRequestOperation *operation, NSError *error);

-(BOOL)performGETAction:(AFHTTPResponseSerializer*)serializer withParams:(NSDictionary *)params andArgs:(AggregatedArgs*)args;
-(BOOL)performPOSTAction:(AFHTTPResponseSerializer*)serializer withParams:(NSDictionary *)params andArgs:(AggregatedArgs*)args;
@end

@implementation OperationsClient

-(void)setupResponseBlocks {
    [self setupSuccessResponseBlock];
    [self setupFailureResponseBlock];
}

-(void)setupSuccessResponseBlock {
    __weak typeof(self) weakSelf = self;
    self.successResponseBlock = ^(AFHTTPRequestOperation *operation, id responseObject) {
        if (!weakSelf) {
            return;
        }
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.progress = NO;
        NSError *error = [strongSelf identifyError:responseObject];
        if (error) {
            strongSelf.failureBlock(error);
        } else {
            strongSelf.successBlock(responseObject);
        }
        [strongSelf clearBlocks];
    };
}

-(void)setupFailureResponseBlock {
    __weak typeof(self) weakSelf = self;
    self.failureResponseBlock = ^(AFHTTPRequestOperation *operation, NSError *error) {
        if (!weakSelf) {
            return;
        }
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.progress = NO;
        strongSelf.failureBlock(error);
        [strongSelf clearBlocks];
    };
}

-(void)clearBlocks {
    _successBlock = nil;
    _failureBlock = nil;
    _failureResponseBlock = nil;
    _successResponseBlock = nil;
}

#pragma mark - Public operations

-(BOOL)performGETAction:(AFHTTPResponseSerializer*)serializer withParams:(NSDictionary *)params andArgs:(AggregatedArgs*)args {
    if (self.progress) {
        return NO;
    }
    
    [self setupCommons:args.success failure:args.failure];
    self.operationManager.responseSerializer = serializer;
    
    [self.operationManager GET:@"index.php" parameters:params success:self.successResponseBlock failure:self.failureResponseBlock];
    
    return YES;
}

-(BOOL)performPOSTAction:(AFHTTPResponseSerializer*)serializer withParams:(NSDictionary *)params andArgs:(AggregatedArgs*)args {
    if (self.progress) {
        return NO;
    }
    
    [self setupCommons:args.success failure:args.failure];
    self.operationManager.responseSerializer = serializer;
    
    [self.operationManager POST:@"index.php" parameters:params success:self.successResponseBlock failure:self.failureResponseBlock];
    
    return YES;
}

-(BOOL)listWorkspacesWithSuccess:(void(^)(NSArray *workspaces))success failure:(FailureBlock)failure {
    
    return [self performGETAction:[self responseSerializerForGetRegisters]
                       withParams:[self paramsForGetRegisters]
                          andArgs:[AggregatedArgs argsWith:success failure:failure]];
}

-(BOOL)listFiles:(NSDictionary*)params WithSuccess:(void(^)(NSArray* files))success failure:(FailureBlock)failure {
    return [self performGETAction:[self responseSerializerForListFiles]
                       withParams:[self paramsForLs:params]
                          andArgs:[AggregatedArgs argsWith:success failure:failure]];
}

-(BOOL)mkdir:(NSDictionary*)params WithSuccess:(void(^)(NSArray* files))success failure:(FailureBlock)failure {
    return [self performPOSTAction:[self responseSerializerForSuccessResponseToAction:@"mkdir"]
                        withParams:[self paramsForMkDir:params]
                           andArgs:[AggregatedArgs argsWith:success failure:failure]];
}

-(BOOL)deleteNodes:(NSDictionary*)params WithSuccess:(void(^)())success failure:(FailureBlock)failure {
    return [self performPOSTAction:[self responseSerializerForSuccessResponseToAction:@"delete"]
                        withParams:[self paramsForDeleteNodes:params]
                           andArgs:[AggregatedArgs argsWith:success failure:failure]];
}

#pragma mark - Helper methods

-(void)setupCommons:(void(^)(id result))success failure:(FailureBlock)failure {
    self.progress = YES;
    
    self.operationManager.requestSerializer = [self defaultRequestSerializer];
    
    self.successBlock = success;
    self.failureBlock = failure;
    [self setupResponseBlocks];
}

-(NSDictionary*)paramsWithTokenIfNeeded:(NSDictionary*)params forAction:(NSString*)action {
    NSString *secureToken = [[ServersParamsManager sharedManager] secureTokenForServer:self.operationManager.baseURL];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:params];
    
    if (secureToken) {
        [dict setValue:secureToken forKey:@"secure_token"];
    }
    [dict setValue:action forKey:@"get_action"];
    
    return [NSDictionary dictionaryWithDictionary:dict];
}

-(NSDictionary*)paramsForGetRegisters {
    NSDictionary *dict = [NSDictionary dictionaryWithObject:@"user/repositories" forKey:@"xPath"];
    return [self paramsWithTokenIfNeeded:dict forAction:@"get_xml_registry"];
}

-(NSDictionary*)paramsForLs:(NSDictionary*)params {
    return [self paramsWithTokenIfNeeded:params forAction:@"ls"];
}

-(NSDictionary*)paramsForMkDir:(NSDictionary*)params {
    return [self paramsWithTokenIfNeeded:params forAction:@"mkdir"];
}

-(NSDictionary*)paramsForDeleteNodes:(NSDictionary*)params {
    return [self paramsWithTokenIfNeeded:params forAction:@"delete"];
}

-(AFHTTPRequestSerializer*)defaultRequestSerializer {
    AFHTTPRequestSerializer *serializer = [AFHTTPRequestSerializer serializer];
    [serializer setValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];
    [serializer setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    [serializer setValue:@"en-us" forHTTPHeaderField:@"Accept-Language"];
    [serializer setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
    [serializer setValue:@"true" forHTTPHeaderField:@"Ajxp-Force-Login"];
    [serializer setValue:@"ajaxplorer-ios-client/1.0" forHTTPHeaderField:@"User-Agent"];
    
    return serializer;
}

-(AFHTTPResponseSerializer*)responseSerializerForGetRegisters {
    NSArray *serializers = [self defaultResponseSerializersWithSerializer:[self createSerializerForRepositories]];
    
    return [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:serializers];
}

-(AFHTTPResponseSerializer*)responseSerializerForListFiles {
    NSArray *serializers = [self defaultResponseSerializersWithSerializer:[self createSerializerForListFiles]];
    
    return [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:serializers];
}

-(AFHTTPResponseSerializer*)responseSerializerForSuccessResponseToAction:(NSString*)name {
    NSArray *serializers = [self defaultResponseSerializersWithSerializer:[self createSerializerForSuccessResponseToAction:name]];
    
    return [AFCompoundResponseSerializer compoundSerializerWithResponseSerializers:serializers];
}

-(NSArray*)defaultResponseSerializersWithSerializer:(XMLResponseSerializer*)serializer {
    return @[
             [self createSerializerForNotAuthorized],
             [self createSerializerForErrorResponse],
             serializer,
             [self createFailingSerializer]
             ];
}

-(XMLResponseSerializer*)createSerializerForNotAuthorized {
    NotAuthorizedResponseSerializerDelegate *delegate = [[NotAuthorizedResponseSerializerDelegate alloc] init];
    return [[XMLResponseSerializer alloc] initWithDelegate:delegate];
}

-(XMLResponseSerializer*)createSerializerForErrorResponse {
    ErrorResponseSerializerDelegate *delegate = [[ErrorResponseSerializerDelegate alloc] init];
    return [[XMLResponseSerializer alloc] initWithDelegate:delegate];
}

-(XMLResponseSerializer*)createSerializerForRepositories {
    WorkspacesResponseSerializerDelegate *delegate = [[WorkspacesResponseSerializerDelegate alloc] init];
    return [[XMLResponseSerializer alloc] initWithDelegate:delegate];
}

-(XMLResponseSerializer*)createSerializerForListFiles {
    ListFilesResponseSerializerDelegate *delegate = [[ListFilesResponseSerializerDelegate alloc] init];
    return [[XMLResponseSerializer alloc] initWithDelegate:delegate];
}

-(XMLResponseSerializer*)createSerializerForSuccessResponseToAction:(NSString*)name {
    SuccessResponseSerializerDelegate *delegate = [[SuccessResponseSerializerDelegate alloc] initWithAction:name];
    return [[XMLResponseSerializer alloc] initWithDelegate:delegate];
}

-(FailingResponseSerializer*)createFailingSerializer {
    return [[FailingResponseSerializer alloc] init];
}

-(NSError *)identifyError:(id)potentialError {
    NSError *error = nil;
    if ([potentialError isKindOfClass:[NotAuthorizedResponse class]]) {
        error = [NSError errorWithDomain:PydioErrorDomain code:PydioErrorRequireAuthorization userInfo:nil];
    } else if ([potentialError isKindOfClass:[PydioErrorResponse class]]) {
        error = [NSError errorWithDomain:PydioErrorDomain code:PydioErrorErrorResponse userInfo:
                 @{NSLocalizedFailureReasonErrorKey: [potentialError message]}];
    }
    
    return error;
}

@end
