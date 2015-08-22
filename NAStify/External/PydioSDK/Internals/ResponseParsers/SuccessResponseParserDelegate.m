//
//  MkdirResponseParserDelegate.m
//  PydioSDK
//
//  Created by Michal Kloczko on 20/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "SuccessResponseParserDelegate.h"

static NSString * const TREE_NODE = @"tree";
static NSString * const MESSAGE_NODE = @"message";
static NSString * const TYPE_ATTRIBUTE = @"type";
static NSString * const TYPE_ATTRIBUTE_VALUE = @"SUCCESS";

typedef NS_ENUM(NSUInteger,State) {
    InitialState,
    ExpectSuccessMessageStart,
    IgnoreState
};

@interface SuccessResponseParserDelegate ()
@property (nonatomic,assign) State state;
@property (readwrite,nonatomic,assign) BOOL success;
@end

@implementation SuccessResponseParserDelegate

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
        self.state = ExpectSuccessMessageStart;
    } else if (self.state == ExpectSuccessMessageStart && [elementName isEqualToString:MESSAGE_NODE] && [[attributeDict valueForKey:TYPE_ATTRIBUTE] isEqualToString:TYPE_ATTRIBUTE_VALUE]) {
        self.success = YES;
        self.state = IgnoreState;
    } else if (self.state != IgnoreState) {
        [parser abortParsing];
    }
    
}

@end
