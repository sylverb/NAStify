//
//  CookieManager.m
//  PydioSDK
//
//  Created by ME on 12/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "ServersParamsManager.h"
#import "NSURL+Normalization.h"


static NSString * const COOKIE_NAME = @"AjaXplorer";
static ServersParamsManager *manager = nil;

@interface ServersParamsManager ()
@property (nonatomic,strong) NSMutableDictionary *users;
@property (nonatomic,strong) NSMutableDictionary *tokens;
@property (nonatomic,strong) NSMutableDictionary *seeds;
@end

@implementation ServersParamsManager

-(instancetype)init {
    self = [super init];
    if (self) {
        self.users = [NSMutableDictionary dictionary];
        self.tokens = [NSMutableDictionary dictionary];
        self.seeds = [NSMutableDictionary dictionary];
    }
    
    return self;
}

+(ServersParamsManager*)sharedManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[ServersParamsManager alloc] init];
    });
    
    return manager;
}

-(NSArray *)allServerCookies:(NSURL *)server {
    return [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[server normalized]];
}

-(void)clearAllCookies:(NSURL *)server {
    NSArray *cookies = [self allServerCookies:server];
    for (NSHTTPCookie *cookie in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
}

-(BOOL)isCookieSet:(NSURL *)server {
    NSArray *cookies = [self allServerCookies:server];
    for (NSHTTPCookie *cookie in cookies) {
        if ([COOKIE_NAME isEqualToString:cookie.name]) {
            return YES;
        }
    }
    return NO;
}

-(void)setUser:(User*)user ForServer:(NSURL *)server {
    [self.users setValue:user forKey:[self serverKey:server]];
}

-(User*)userForServer:(NSURL *)server {
    return [self.users valueForKey:[self serverKey:server]];
}

-(void)setSecureToken:(NSString*)token ForServer:(NSURL *)server {
    [self.tokens setValue:token forKey:[self serverKey:server]];
}

-(NSString*)secureTokenForServer:(NSURL *)server {
    return [self.tokens valueForKey:[self serverKey:server]];
}

-(void)clearSecureToken:(NSURL *)server {
    [self.tokens removeObjectForKey:[self serverKey:server]];
}

-(void)setSeed:(NSString *)token ForServer:(NSURL *)server {
    [self.seeds setValue:token forKey:[self serverKey:server]];
}

-(NSString*)seedForServer:(NSURL *)server {
    return [self.seeds valueForKey:[self serverKey:server]];
}

-(void)clearSeed:(NSURL *)server {
    [self.seeds removeObjectForKey:[self serverKey:server]];
}

-(NSArray*)serversList {
    NSMutableArray *array = [NSMutableArray array];
    for (NSString *server in [self.users allKeys]) {
        [array addObject:[NSURL URLWithString:server]];
    }
    
    return [NSArray arrayWithArray:array];
}

-(NSString*)serverKey:(NSURL*)url {
    return [[url normalized] absoluteString];
}

@end
