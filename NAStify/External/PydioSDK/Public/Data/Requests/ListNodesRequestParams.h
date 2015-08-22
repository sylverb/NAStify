//
//  ListFilesRequest.h
//  PydioSDK
//
//  Created by ME on 06/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ListNodesRequestParams : NSObject
@property (nonatomic,strong) NSString* workspaceId;
@property (nonatomic,strong) NSString* path;
@property (nonatomic,strong) NSDictionary* additional;

-(NSDictionary *)dictionaryRepresentation;
@end
