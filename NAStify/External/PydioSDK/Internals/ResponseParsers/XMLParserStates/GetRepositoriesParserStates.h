//
//  RepositoriesParserStates.h
//  PydioSDK
//
//  Created by ME on 20/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XMLParserState.h"
#import "RepositoriesParserDelegate.h"

@interface InitialGetReposParserState : XMLParserState
@end

@interface ExpectStartRepoState : XMLParserState
@end

@interface ExpectEndRepoState : XMLParserState
@property (nonatomic,weak) RepositoriesParserDelegate *delegate;

@property (nonatomic,strong) NSString *repoId;
@property (nonatomic,strong) NSString *label;
@property (nonatomic,strong) NSString *description;
@end
