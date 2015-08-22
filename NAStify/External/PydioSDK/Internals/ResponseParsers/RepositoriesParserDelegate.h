//
//  RepositoriesResponseParser.h
//  PydioSDK
//
//  Created by ME on 19/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ParserStateDelgate.h"

@interface RepositoriesParserDelegate : NSObject<NSXMLParserDelegate,ParserStateDelgate>
@property (readonly,nonatomic,strong) NSArray* repositories;
@end
