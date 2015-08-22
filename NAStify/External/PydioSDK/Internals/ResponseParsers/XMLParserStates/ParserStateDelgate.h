//
//  ParserStateDelgate.h
//  PydioSDK
//
//  Created by ME on 02/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XMLParserState;

@protocol ParserStateDelgate <NSObject>
@property (nonatomic,strong) XMLParserState *parserState;
@end
