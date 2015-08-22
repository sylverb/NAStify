//
//  File.h
//  PydioSDK
//
//  Created by ME on 02/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NodeResponse : NSObject
@property (nonatomic,weak) NodeResponse* parent;
@property (nonatomic,strong) NSString* name;
@property (nonatomic,assign) BOOL isLeaf;
@property (nonatomic,strong) NSString* path;
@property (nonatomic,assign) NSInteger size;
@property (nonatomic,strong) NSDate* mTime;
@property (nonatomic,strong) NSArray *children;

-(NSString*)fullPath;
-(BOOL)isTreeEqual:(NodeResponse*)node;
-(BOOL)isValuesEqual:(NodeResponse*)other;
@end
