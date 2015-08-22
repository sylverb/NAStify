//
//  SeedResponse.h
//  PydioSDK
//
//  Created by Michal Kloczko on 01/03/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SeedResponse : NSObject
@property (readonly,nonatomic,strong) NSString *seed;
@property (readonly,nonatomic,assign) BOOL captcha;

+(SeedResponse*)seedWithCaptcha:(NSString*)seed;
+(SeedResponse*)seed:(NSString*)seed;

-(instancetype)init:(NSString*)seed;
-(instancetype)initWithCaptcha:(NSString*)seed;
@end
