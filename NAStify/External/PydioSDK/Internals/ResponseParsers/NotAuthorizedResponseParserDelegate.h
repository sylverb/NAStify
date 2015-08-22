//
//  XMLResponseBuilder.h
//  PydioSDK
//
//  Created by ME on 04/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NotAuthorizedResponseParserDelegate : NSObject<NSXMLParserDelegate>
@property (readonly,nonatomic,assign) BOOL notLogged;
@end
