//
//  MkDirRequestParams.m
//  PydioSDK
//
//  Created by Michal Kloczko on 23/02/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "MkDirRequestParams.h"

@implementation MkDirRequestParams

-(NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjects:@[self.workspaceId,self.dir,self.dirname]
                                                                     forKeys:@[@"tmp_repository_id", @"dir",@"dirname"]];
    
    for (NSString *key in [self.additional allKeys]) {
        [params setValue:[self.additional valueForKey:key] forKey:key];
    }
    
    return [NSDictionary dictionaryWithDictionary:params];
}

@end
