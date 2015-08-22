//
//  ListFilesResponseParserDelegate.h
//  PydioSDK
//
//  Created by ME on 01/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ParserStateDelgate.h"

@interface ListFilesResponseParserDelegate : NSObject<NSXMLParserDelegate>
@property (readonly,nonatomic,strong) NSArray* files;
@end
