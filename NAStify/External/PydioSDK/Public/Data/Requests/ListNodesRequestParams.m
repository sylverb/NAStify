//
//  ListFilesRequest.m
//  PydioSDK
//
//  Created by ME on 06/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "ListNodesRequestParams.h"

@implementation ListNodesRequestParams

-(NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjects:@[self.workspaceId,self.path,@"al"]
                                                                     forKeys:@[@"tmp_repository_id", @"dir", @"options"]];
    
    for (NSString *key in [self.additional allKeys]) {
        [params setValue:[self.additional valueForKey:key] forKey:key];
    }
    
    return [NSDictionary dictionaryWithDictionary:params];
}

@end
