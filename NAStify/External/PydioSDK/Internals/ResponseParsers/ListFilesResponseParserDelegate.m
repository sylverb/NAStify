//
//  ListFilesResponseParserDelegate.m
//  PydioSDK
//
//  Created by ME on 01/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "ListFilesResponseParserDelegate.h"
#import "NodeResponse.h"


static NSString * const TREE_NODE = @"tree";
static NSString * const FILENAME_ELEMENT = @"filename";
static NSString * const IS_FILE_ELEMENT = @"is_file";
static NSString * const TEXT_ELEMENT = @"text";
static NSString * const BYTESIZE_ELEMENT = @"bytesize";
static NSString * const MODIFTIME_ELEMENT = @"ajxp_modiftime";

#pragma mark -

@implementation NSDictionary (ListFilesParserState)

-(NSString*)filename {
    return [self valueForKey:FILENAME_ELEMENT];
}

-(NSString*)text {
    return [self valueForKey:TEXT_ELEMENT];
}

-(NSString*)isLeaf {
    return [self valueForKey:IS_FILE_ELEMENT];
}

-(NSString*)bytesize {
    return [self valueForKey:BYTESIZE_ELEMENT];
}

-(NSString*)modiftime {
    return [self valueForKey:MODIFTIME_ELEMENT];
}

@end

#pragma mark -

@interface ListFilesResponseParserDelegate ()
@property (nonatomic,strong) NSMutableArray *parentsStack;
@end


@implementation ListFilesResponseParserDelegate {
    NSMutableArray *_files;
}

-(instancetype)init {
    self = [super init];
    if (self) {
        self.parentsStack = [NSMutableArray array];
        _files = [NSMutableArray array];
    }
    
    return self;
}

-(NSArray*)files {
    return [NSArray arrayWithArray:_files];
}

-(void)appendFile:(NodeResponse*)file {
    [_files addObject:file];
}

-(NodeResponse*)createFileNode:(NSDictionary*)attributes {
    NodeResponse *file = [[NodeResponse alloc] init];
    file.name = [attributes text];
    file.isLeaf = [[attributes isLeaf] isEqualToString:@"true"];
    file.path = [attributes filename];
    file.size = [[attributes bytesize] integerValue];
    file.mTime = [NSDate dateWithTimeIntervalSince1970:[[attributes modiftime] doubleValue]];
    
    return file;
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqualToString:TREE_NODE] && [attributeDict filename] != nil) {
        NodeResponse *node = [self createFileNode:attributeDict];
        node.parent = [self.parentsStack lastObject];
        if (!node.parent.children) {
            node.parent.children = [NSArray arrayWithObject:node];
        } else {
            node.parent.children = [node.parent.children arrayByAddingObject:node];
        }
        
        [self.parentsStack addObject:node];
    } else {
        [parser abortParsing];
    }
}

-(void)parser:(NSXMLParser*)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqualToString:TREE_NODE]) {
        NodeResponse *node = [self.parentsStack lastObject];
        [self.parentsStack removeLastObject];
        if (self.parentsStack.count == 0) {
            [_files addObject:node];
        }
    } else {
        [parser abortParsing];
    }
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {

}

@end
