//
//  DeleteNodesRequestParams.h
//  PydioSDK
//
//  Created by Michal Kloczko on 23/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DeleteNodesRequestParams : NSObject
@property (nonatomic,strong) NSString* workspaceId;
@property (nonatomic,strong) NSArray* nodes;
@property (nonatomic,strong) NSDictionary* additional;

-(NSDictionary *)dictionaryRepresentation;
@end
