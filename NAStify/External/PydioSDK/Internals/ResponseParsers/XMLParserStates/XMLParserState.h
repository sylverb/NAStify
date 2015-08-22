//
//  XMLParserState.h
//  PydioSDK
//
//  Created by ME on 02/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RepositoriesParserDelegate;
@protocol ParserStateDelgate;

@interface XMLParserState : NSObject
@property (nonatomic,weak) NSObject<ParserStateDelgate> *delegate;
@property (nonatomic,strong) NSString* buffer;

-(instancetype)initWithDelegate:(NSObject<ParserStateDelgate>*)delegate;
-(void)didStartElement:(NSString *)elementName attributes:(NSDictionary *)attributeDict;
-(void)didEndElement:(NSString *)elementName;
-(void)foundCharacters:(NSString *)string;
@end
