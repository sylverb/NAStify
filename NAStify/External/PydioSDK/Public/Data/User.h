//
//  User.h
//  PydioSDK
//
//  Created by ME on 13/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface User : NSObject
@property(readonly,nonatomic,strong) NSString* userid;
@property(readonly,nonatomic,strong) NSString* password;

+(instancetype)userWithId:(NSString*)userid AndPassword:(NSString*)password;
-(instancetype)initWithId:(NSString*)userid AndPassword:(NSString*)password;
@end
