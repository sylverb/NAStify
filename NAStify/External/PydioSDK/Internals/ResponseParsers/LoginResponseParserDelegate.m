//
//  LoginXMLResponseParser.m
//  PydioSDK
//
//  Created by ME on 04/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "LoginResponseParserDelegate.h"

@interface LoginResponseParserDelegate ()
@property (nonatomic,assign) SEL startElementAction;

-(void)treeElementStart:(NSString*)elementName Attributes:(NSDictionary *)attributes;
-(void)loggingResultElementStart:(NSString*)elementName Attributes:(NSDictionary *)attributes;
@end

@implementation LoginResponseParserDelegate

-(instancetype)init {
    self = [super init];
    if (self) {
        self.startElementAction = @selector(treeElementStart:Attributes:);
    }
    
    return self;
}

#pragma mark -

-(void)treeElementStart:(NSString*)elementName Attributes:(NSDictionary *)attributes {
    if ([elementName compare:@"tree"] == NSOrderedSame) {
        self.startElementAction = @selector(loggingResultElementStart:Attributes:);
    }
}


-(void)loggingResultElementStart:(NSString*)elementName Attributes:(NSDictionary *)attributes {
    if ([elementName compare:@"logging_result"] == NSOrderedSame) {
        _resultValue = [attributes valueForKey:@"value"];
        if ([self.resultValue compare:@"1"] == NSOrderedSame) {
            _secureToken = [attributes valueForKey:@"secure_token"];
        }
        
        self.startElementAction = nil;
    }
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if (self.startElementAction) {
        [self performSelector:self.startElementAction withObject:elementName withObject:attributeDict];
    }
#pragma clang diagnostic pop
}
@end
