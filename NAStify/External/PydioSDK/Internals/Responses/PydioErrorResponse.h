//
//  PydioErrorResponse.h
//  PydioSDK
//
//  Created by ME on 17/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PydioErrorResponse : NSObject
@property (readonly,nonatomic,strong) NSString* message;

+(instancetype)errorResponseWithString:(NSString*)message;
-(instancetype)initWithString:(NSString*)message;
@end
