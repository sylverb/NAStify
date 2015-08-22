//
//  RepositoriesParserStates.m
//  PydioSDK
//
//  Created by ME on 20/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "GetRepositoriesParserStates.h"
#import "WorkspaceResponse.h"


@interface RepositoriesParserDelegate ()
-(void)appendRepository:(WorkspaceResponse*)repo;
@end


#pragma mark - Get Repositories Parser state

@implementation InitialGetReposParserState

-(void)didStartElement:(NSString *)elementName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqualToString:@"repositories"]) {
        self.delegate.parserState = [[ExpectStartRepoState alloc] initWithDelegate:self.delegate];
    }
}

@end


@implementation ExpectStartRepoState

-(void)didStartElement:(NSString *)elementName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqualToString:@"repo"] && [attributeDict valueForKey:@"id"]) {
        ExpectEndRepoState *endRepoState = [[ExpectEndRepoState alloc] initWithDelegate:self.delegate];
        endRepoState.repoId = [attributeDict valueForKey:@"id"];
        self.delegate.parserState = endRepoState;
    }
}

@end


@implementation ExpectEndRepoState
-(void)didStartElement:(NSString *)elementName attributes:(NSDictionary *)attributeDict {
    self.buffer = @"";
}

-(void)didEndElement:(NSString *)elementName {
    if (!self.label && [elementName isEqualToString:@"label"]) {
        self.label = self.buffer;
    } else if (!self.description && [elementName isEqualToString:@"description"]) {
        self.description = self.buffer;
    } else if ([elementName isEqualToString:@"repo"]) {
        WorkspaceResponse *repo = [[WorkspaceResponse alloc] initWithId:self.repoId AndLabel:self.label AndDescription:self.description];
        [self.delegate appendRepository:repo];
        self.delegate.parserState = [[ExpectStartRepoState alloc] initWithDelegate:self.delegate];
    }
}

@end
