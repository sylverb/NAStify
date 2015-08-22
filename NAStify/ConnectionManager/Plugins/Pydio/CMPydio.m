//
//  CMPydio.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2015 CodeIsALie. All rights reserved.
//

#import "CMPydio.h"
#import "SSKeychain.h"
#import "PydioClient.h"
#import "User.h"
#import "ListNodesRequestParams.h"
#import "ServersParamsManager.h"
#import "WorkspaceResponse.h"
#import "NodeResponse.h"
#import "PydioErrors.h"

@implementation CMPydio

- (id)init
{
    self = [super init];
    if (self)
    {
    }
    return self;
}

-(NSString *)createURL
{
    return [NSString stringWithFormat:@"http://%@",self.userAccount.server];
}

-(PydioClient *)pydioClient
{
    return [[PydioClient alloc] initWithServer:[self createURL]];
}

- (NSString *)stringByDeletingFirstPathComponent:(NSString *)path
{
    NSString *result = nil;
    NSArray* pathComponents = [path pathComponents];
    
    if ([pathComponents count] > 2) {
        NSArray *array = [pathComponents subarrayWithRange:NSMakeRange(2,[pathComponents count]-2)];
        result = [NSString pathWithComponents:array];
    }
    else
    {
        result = @"/";
    }
    return result;
}
#pragma mark - Server Info

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           [NSString stringWithFormat:NSLocalizedString(@"Server Name : %@",nil),@""],
                           [NSString stringWithFormat:NSLocalizedString(@"Type : %@",nil), @""],
                           [NSString stringWithFormat:NSLocalizedString(@"%@",nil), @""],
                           nil];
    return serverInfo;
}

#pragma mark - login/logout management

- (BOOL)login
{
    NSString *password = [SSKeychain passwordForService:self.userAccount.uuid
                                                account:@"password"];
    
    ServersParamsManager *manager = [ServersParamsManager sharedManager];
    User* user = [User userWithId:self.userAccount.userName AndPassword:password];
    [manager setUser:user ForServer:[NSURL URLWithString:[self createURL]]];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

    [self.pydioClient listWorkspacesWithSuccess:^(NSArray *files) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

        self.workspaces = files;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    nil]];
        });
    } failure:^(NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

        if (error.code == PydioErrorGetSeedWithCaptcha || error.code == PydioErrorLoginWithCaptcha) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        @"Need to load captch",@"error",
                                        nil]];
            });
        }
    }];
    return YES;
}

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
    if ([folder.path isEqualToString:@"/"])
    {
        NSMutableArray *filesOutputArray = [NSMutableArray arrayWithCapacity:[self.workspaces count]];
        
        for (WorkspaceResponse *response in self.workspaces)
        {
            if ((![response.workspaceId isEqualToString:@"ajxp_user"]) &&
                (![response.workspaceId isEqualToString:@"ajxp_home"]))
            {
                NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithBool:YES],@"isdir",
                                          response.label,@"filename",
                                          @"/",@"path",
                                          response.workspaceId,@"id",
                                          [NSNumber numberWithBool:NO],@"writeaccess",
                                          nil];
                [filesOutputArray addObject:dictItem];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES],@"success",
                                        folder.path,@"path",
                                        filesOutputArray,@"filesList",
                                        nil]];
        });
    }
    else
    {
        ListNodesRequestParams *request = [[ListNodesRequestParams alloc] init];
        request.workspaceId = [folder.objectIds lastObject];
        request.path = [self stringByDeletingFirstPathComponent:folder.path];
//       request.additional = @{
//                              @"recursive": @"true",
//                              @"max_depth" : @"2"
//                              };
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

        [self.pydioClient listNodes:request
                        WithSuccess:^(NSArray *files) {
                            // End the network activity spinner
                            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                            
                            NSMutableArray *filesOutputArray = [[NSMutableArray alloc] init];
                            
                            for (NodeResponse *response in files)
                            {
                                for (NodeResponse *child in response.children)
                                {
                                    NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                                              [NSNumber numberWithBool:!child.isLeaf],@"isdir",
                                                              child.name,@"filename",
                                                              folder.path,@"path",
                                                              [NSNumber numberWithBool:NO],@"writeaccess",
                                                              [NSNumber numberWithDouble:[child.mTime timeIntervalSince1970]],@"date",
                                                              [NSString stringForSize:child.size],@"filesize",
                                                              [NSNumber numberWithDouble:child.size],@"filesizenumber",
                                                              nil];
                                    
                                    [filesOutputArray addObject:dictItem];
                                    
                                }
                            }
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                            [NSNumber numberWithBool:YES],@"success",
                                                            folder.path,@"path",
                                                            filesOutputArray,@"filesList",
                                                            nil]];
                            });
                        } failure:^(NSError *error) {
                            // End the network activity spinner
                            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                            
                            NSLog(@"%s %@",__PRETTY_FUNCTION__,error);
                        }
         ];
    }
}

#pragma mark - Download management

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
}

- (void)cancelDownloadTask
{
}

#pragma mark - url management

- (NetworkConnection *)urlForFile:(FileItem *)file
{
  	return nil;
}

#pragma mark - supported features

- (long long)supportedFeaturesAtPath:(NSString *)path
{
    long long features = CMSupportedFeaturesMaskVLCPlayer      |
                         CMSupportedFeaturesMaskQTPlayer       |
                         CMSupportedFeaturesMaskGoogleCast     |
                         CMSupportedFeaturesMaskCacheImage;
    return features;
}

@end
