//
//  MkdirResponseParserDelegate.h
//  PydioSDK
//
//  Created by Michal Kloczko on 20/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SuccessResponseParserDelegate : NSObject<NSXMLParserDelegate>
@property (readonly,nonatomic,assign) BOOL success;
@end
