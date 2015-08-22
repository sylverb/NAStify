//
//  MkDirRequestParams.h
//  PydioSDK
//
//  Created by Michal Kloczko on 23/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MkDirRequestParams : NSObject
@property (nonatomic,strong) NSString* workspaceId;
@property (nonatomic,strong) NSString* dir;
@property (nonatomic,strong) NSString* dirname;
@property (nonatomic,strong) NSDictionary* additional;

-(NSDictionary *)dictionaryRepresentation;
@end
