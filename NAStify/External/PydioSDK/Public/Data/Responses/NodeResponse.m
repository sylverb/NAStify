//
//  File.m
//  PydioSDK
//
//  Created by ME on 02/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "NodeResponse.h"

@implementation NodeResponse

-(NSString*)fullPath {
    
    NSString *path = self.path;
    NodeResponse *node = self;
    
    while (node.parent) {
        path = [NSString stringWithFormat:@"%@%@",node.parent,path];
        node = node.parent;
    }
    
    return path;
}

-(BOOL)isTreeEqual:(NodeResponse*)other {
    BOOL result = [self isValuesEqual:other] && self.children.count == other.children.count;
    
    NSUInteger i = 0;
    while (result && i < self.children.count) {
        NodeResponse *myChild = [self.children objectAtIndex:i];
        NodeResponse *otherChild = [other.children objectAtIndex:i];
        
        result = [myChild isTreeEqual:otherChild];
        ++i;
    }
    
    return result;
}

-(BOOL)isValuesEqual:(NodeResponse*)other {
    if (self == other) {
        return YES;
    }

    if (self.name != other.name && ![self.name isEqualToString:other.name]) {
        return NO;
    }
    
    if (self.isLeaf != other.isLeaf) {
        return NO;
    }
    
    if (self.path != other.path && ![self.path isEqualToString:other.path]) {
        return NO;
    }
    
    if (self.size != other.size) {
        return NO;
    }
    
    if (self.mTime != other.mTime && ![self.mTime isEqual:other.mTime]) {
        return NO;
    }

    return YES;
}

@end
