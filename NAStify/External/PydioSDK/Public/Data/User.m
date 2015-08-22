//
//  User.m
//  PydioSDK
//
//  Created by ME on 13/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "User.h"

@interface User ()
@property(readwrite,nonatomic,strong) NSString* userid;
@property(readwrite,nonatomic,strong) NSString* password;
@end

@implementation User

+(instancetype)userWithId:(NSString*)userid AndPassword:(NSString*)password
{
    return [[User alloc] initWithId:userid AndPassword:password];
}

-(instancetype)initWithId:(NSString*)userid AndPassword:(NSString*)password
{
    self = [super init];
    if (self) {
        _userid = userid;
        _password = password;
    }
    return self;
}

-(BOOL)isEqual:(id)object {
    if (object == nil || ![object isKindOfClass:[User class]]) {
        return NO;
    }
    if (self == object) {
        return YES;
    }
    
    User *other = (User*)object;
    return [self.userid isEqualToString:other.userid] && [self.password isEqualToString:other.password];
}

-(NSUInteger)hash {
    return [[NSString stringWithFormat:@"%@%@",self.userid,self.password] hash];
}
@end
