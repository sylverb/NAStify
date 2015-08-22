//
//  XMLParserState.m
//  PydioSDK
//
//  Created by ME on 02/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "XMLParserState.h"

@implementation XMLParserState

-(instancetype)initWithDelegate:(NSObject<ParserStateDelgate>*)delegate {
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.buffer = @"";
    }
    
    return self;
}

-(void)didStartElement:(NSString *)elementName attributes:(NSDictionary *)attributeDict {
    
}

-(void)didEndElement:(NSString *)elementName {
    
}

-(void)foundCharacters:(NSString *)string {
    self.buffer = [self.buffer stringByAppendingString:string];
}

@end
