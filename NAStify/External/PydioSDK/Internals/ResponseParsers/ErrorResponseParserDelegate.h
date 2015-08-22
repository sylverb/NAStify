//
//  ErrorResponseParserDelegate.h
//  PydioSDK
//
//  Created by ME on 10/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ErrorResponseParserDelegate : NSObject<NSXMLParserDelegate>
@property (readonly,nonatomic,strong) NSString* errorMessage;
@end
