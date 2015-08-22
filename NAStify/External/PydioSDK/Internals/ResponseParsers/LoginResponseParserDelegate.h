//
//  LoginXMLResponseParser.h
//  PydioSDK
//
//  Created by ME on 04/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LoginResponseParserDelegate : NSObject<NSXMLParserDelegate>
@property (readonly,nonatomic,strong) NSString *resultValue;
@property (readonly,nonatomic,strong) NSString *secureToken;
@end
