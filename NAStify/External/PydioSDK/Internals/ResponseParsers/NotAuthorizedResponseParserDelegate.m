//
//  XMLResponseBuilder.m
//  PydioSDK
//
//  Created by ME on 04/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "NotAuthorizedResponseParserDelegate.h"

typedef NS_ENUM(NSUInteger,DelegateState) {
    InitialState,
    ExpectRequireAuthStart,
    ExpectAjxpRegistryPartEnd,
    IgnoreState
};

@interface NotAuthorizedResponseParserDelegate ()
@property (nonatomic,assign) DelegateState state;
@end


@implementation NotAuthorizedResponseParserDelegate

-(instancetype)init {
    self = [super init];
    if (self) {
        self.state = InitialState;
        _notLogged = NO;
    }
    
    return self;
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    if (self.state == InitialState) {
        if ([elementName isEqualToString:@"tree"]) {
            self.state = ExpectRequireAuthStart;
        } else if ([elementName isEqualToString:@"ajxp_registry_part"] && attributeDict.count == 1 && [[attributeDict valueForKey:@"xPath"] isEqualToString:@"user/repositories"]){
            self.state = ExpectAjxpRegistryPartEnd;
        } else {
            [parser abortParsing];
        }
    } else if (self.state == ExpectRequireAuthStart && [elementName isEqualToString:@"require_auth"]) {
        _notLogged = YES;
        self.state = IgnoreState;
    } else if (self.state == IgnoreState) {
        
    } else {
        [parser abortParsing];
    }
}

- (void)parser:(NSXMLParser*)parser didEndElement:(NSString*)elementName namespaceURI:(NSString*)namespaceURI qualifiedName:(NSString *)qName {
    if (self.state == ExpectAjxpRegistryPartEnd && [elementName isEqualToString:@"ajxp_registry_part"]) {
        _notLogged = YES;
        self.state = IgnoreState;
    } else if (self.state == IgnoreState) {
        
    } else {
        [parser abortParsing];
    }
}

@end
