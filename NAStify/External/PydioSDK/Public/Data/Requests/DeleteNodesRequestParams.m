//
//  DeleteNodesRequestParams.m
//  PydioSDK
//
//  Created by Michal Kloczko on 23/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "DeleteNodesRequestParams.h"

@implementation DeleteNodesRequestParams

-(NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObject:self.workspaceId forKey:@"tmp_repository_id"];
    [params setValue:self.nodes forKey:@"nodes"];
    
    for (NSString *key in [self.additional allKeys]) {
        [params setValue:[self.additional valueForKey:key] forKey:key];
    }
    
    return [NSDictionary dictionaryWithDictionary:params];
}

@end
