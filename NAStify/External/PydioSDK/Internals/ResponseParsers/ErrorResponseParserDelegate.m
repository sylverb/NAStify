//
//  ErrorResponseParserDelegate.m
//  PydioSDK
//
//  Created by ME on 10/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "ErrorResponseParserDelegate.h"


static NSString * const TREE_NODE = @"tree";
static NSString * const MESSAGE_NODE = @"message";
static NSString * const TYPE_ATTRIBUTE = @"type";
static NSString * const TYPE_ATTRIBUTE_VALUE = @"ERROR";

typedef NS_ENUM(NSUInteger,State) {
    InitialState,
    ExpectErrorMessageStart,
    ExpectErrorMessageEnd,
    IgnoreState
};

@interface ErrorResponseParserDelegate ()
@property (readwrite,nonatomic,strong) NSString* errorMessage;

@property (nonatomic,assign) State state;
@property (nonatomic,strong) NSString *buffer;
@end


@implementation ErrorResponseParserDelegate

-(instancetype)init {
    self = [super init];
    if (self) {
        self.state = InitialState;
    }
    return self;
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    if (self.state == InitialState && [elementName isEqualToString:TREE_NODE]) {
        self.state = ExpectErrorMessageStart;
    } else if (self.state == ExpectErrorMessageStart && [elementName isEqualToString:MESSAGE_NODE] && [[attributeDict valueForKey:TYPE_ATTRIBUTE] isEqualToString:TYPE_ATTRIBUTE_VALUE]) {
        self.state = ExpectErrorMessageEnd;
    } else if (self.state != IgnoreState) {
        [parser abortParsing];
    }

    self.buffer = @"";
}

-(void)parser:(NSXMLParser*)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if (self.state == ExpectErrorMessageEnd) {
        self.errorMessage = [NSString stringWithString:self.buffer];
        self.state = IgnoreState;
    }
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    self.buffer = [self.buffer stringByAppendingString:string];
}

@end
