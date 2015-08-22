//
//  CookieManager.h
//  PydioSDK
//
//  Created by ME on 12/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@class User;

@interface ServersParamsManager : NSObject
+(ServersParamsManager*)sharedManager;

-(NSArray *)allServerCookies:(NSURL *)server;
-(void)clearAllCookies:(NSURL *)server;
-(BOOL)isCookieSet:(NSURL *)server;
-(void)setUser:(User*)user ForServer:(NSURL *)server;
-(User*)userForServer:(NSURL *)server;
-(void)setSecureToken:(NSString*)token ForServer:(NSURL *)server;
-(NSString*)secureTokenForServer:(NSURL *)server;
-(void)clearSecureToken:(NSURL *)server;
-(void)setSeed:(NSString *)token ForServer:(NSURL *)server;
-(NSString*)seedForServer:(NSURL *)server;
-(void)clearSeed:(NSURL *)server;
-(NSArray*)serversList;
@end
