//
//  CMBox.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//
//  API documentation : http://developers.box.com/docs
//  box iOS SDK v2 documentation : http://opensource.box.com/box-ios-sdk-v2/index.html

#import "CMBox.h"
#import "BoxAuthorizationNavigationController.h"
#import "SSKeychain.h"
#import "SBNetworkActivityIndicator.h"
#import "private.h"

@implementation CMBox

#pragma mark - Server Info

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           NSLocalizedString(@"Server Type : Box.net",nil),
                           [NSString stringWithFormat:NSLocalizedString(@"User's Name : %@",nil),self.userName],
                           [NSString stringWithFormat:NSLocalizedString(@"accessToken : %@",nil),[BoxSDK sharedSDK].OAuth2Session.accessToken],
                           [NSString stringWithFormat:NSLocalizedString(@"refreshToken : %@",nil),[BoxSDK sharedSDK].OAuth2Session.refreshToken],
                           nil];
    return serverInfo;
}

#pragma mark - login/logout management

- (void)boxAPIHeartbeat
{
    BoxFolderBlock success = ^(BoxFolder *folder)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    nil]];
        });
    };

    BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSLog(@"Error %ld %@",(long)error.code,error.localizedDescription);
    };

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [[BoxSDK sharedSDK].foldersManager folderInfoWithID:@"0" requestBuilder:nil success:success failure:failure];
}

- (BOOL)login
{
    [BoxSDK sharedSDK].OAuth2Session.clientID = BOX_CLIENT_ID;
    [BoxSDK sharedSDK].OAuth2Session.clientSecret = BOX_CLIENT_SECRET;

    [BoxSDK sharedSDK].OAuth2Session.accessToken = nil;
    [BoxSDK sharedSDK].OAuth2Session.refreshToken = [SSKeychain passwordForService:self.userAccount.uuid account:@"token"];
    

    // Login handling
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(boxTokenExpired:)
                                                 name:BoxOAuth2SessionDidReceiveRefreshErrorNotification
                                               object:[BoxSDK sharedSDK].OAuth2Session];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(boxTokensDidRefresh:)
                                                 name:BoxOAuth2SessionDidBecomeAuthenticatedNotification
                                               object:[BoxSDK sharedSDK].OAuth2Session];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(boxTokensDidRefresh:)
                                                 name:BoxOAuth2SessionDidRefreshTokensNotification
                                               object:[BoxSDK sharedSDK].OAuth2Session];

    // Authentication error handling
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(boxDidGetLoggedOut:)
                                                 name:BoxOAuth2SessionDidReceiveAuthenticationErrorNotification
                                               object:[BoxSDK sharedSDK].OAuth2Session];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(boxDidGetLoggedOut:)
                                                 name:BoxOAuth2SessionDidReceiveRefreshErrorNotification
                                               object:[BoxSDK sharedSDK].OAuth2Session];
    [self boxAPIHeartbeat];
    return YES;
}

- (BOOL)logout
{
    // Login handling
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:BoxOAuth2SessionDidReceiveRefreshErrorNotification
                                                   object:[BoxSDK sharedSDK].OAuth2Session];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:BoxOAuth2SessionDidBecomeAuthenticatedNotification
                                                  object:[BoxSDK sharedSDK].OAuth2Session];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:BoxOAuth2SessionDidRefreshTokensNotification
                                                  object:[BoxSDK sharedSDK].OAuth2Session];

    // Authentication error handling
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:BoxOAuth2SessionDidReceiveAuthenticationErrorNotification
                                                  object:[BoxSDK sharedSDK].OAuth2Session];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:BoxOAuth2SessionDidReceiveRefreshErrorNotification
                                                  object:[BoxSDK sharedSDK].OAuth2Session];
    
    return NO;
}

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
    BoxCollectionBlock success = ^(BoxCollection *collection)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

        NSMutableArray *filesOutputArray = nil;
        /* Build dictionary with items */
        filesOutputArray = [NSMutableArray arrayWithCapacity:collection.numberOfEntries];
        for (NSUInteger i = 0; i < collection.numberOfEntries; i++)
        {
            BoxItem *fileItem = (BoxItem *)[collection modelAtIndex:i];
            
            NSMutableDictionary *dictItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [fileItem.type isEqualToString:BoxAPIItemTypeFolder]?@"1":@"0",@"isdir",
                                             fileItem.name,@"filename",
                                             fileItem.modelID,@"id",
                                             @"",@"group",
                                             [NSNumber numberWithBool:YES],@"writeaccess",
                                             nil];
            
            // File size
            if (fileItem.size)
            {
                [dictItem addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                    [NSString stringForSize:[fileItem.size longLongValue]],@"filesize",
                                                    fileItem.size,@"filesizenumber",
                                                    nil]];
            }
            
            // Owner
            if (fileItem.createdBy.name)
            {
                [dictItem addEntriesFromDictionary:[NSDictionary dictionaryWithObject:fileItem.createdBy.name forKey:@"owner"]];
            }
            
            // Date
            if (fileItem.modifiedAt)
            {
                NSNumber *fileDateNumber = [NSNumber numberWithDouble:[fileItem.modifiedAt timeIntervalSince1970]];
                [dictItem addEntriesFromDictionary:[NSDictionary dictionaryWithObject:fileDateNumber forKey:@"date"]];
            }
            
            [filesOutputArray addObject:dictItem];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES],@"success",
                                        [folder.objectIds lastObject],@"id",
                                        filesOutputArray,@"filesList",
                                        nil]];
        });
    };
    
    BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        switch (error.code)
        {
            case BoxSDKOAuth2ErrorAccessTokenExpired:
            case BoxSDKOAuth2ErrorAccessTokenExpiredOperationCannotBeReenqueued:
            case BoxSDKOAuth2ErrorAccessTokenExpiredOperationReachedMaxReenqueueLimit:
            {
                // Do nothing
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                [folder.objectIds lastObject],@"id",
                                                [error localizedDescription],@"error",
                                                nil]];
                });
                break;
            }
        }
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    NSString *boxFolderID;
    if ([[folder.objectIds lastObject] isEqual:kRootID])
    {
        boxFolderID = BoxAPIFolderIDRoot;
    }
    else
    {
        boxFolderID = [folder.objectIds lastObject];
    }
    //FIXME: remove the 1000 items limit by doing as much requests as needed with increasing offset field value
    BoxFoldersRequestBuilder *reqBuilder = [[BoxFoldersRequestBuilder alloc] initWithQueryStringParameters:@{
                                                                        @"fields" : @"name,type,id,size,modified_at,created_by",
                                                                        @"limit" : @(1000),
                                                                        @"offset" : @(0)}];
    [[BoxSDK sharedSDK].foldersManager folderItemsWithID:boxFolderID
                                          requestBuilder:reqBuilder
                                                 success:success
                                                 failure:failure];
}

#pragma mark - space info management

- (void)spaceInfoAtPath:(FileItem *)folder
{
    BoxUserBlock success = ^(BoxUser *user)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        self.userName = user.name;
        
        long long totalSpace = [user.spaceAmount longLongValue];
        long long usedSpace = [user.spaceUsed longLongValue];
        long long freeSpace = totalSpace - usedSpace;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMSpaceInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES],@"success",
                                        [NSNumber numberWithLongLong:totalSpace],@"totalspace",
                                        [NSNumber numberWithLongLong:freeSpace],@"freespace",
                                        nil]];
        });
    };
    
    BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [[BoxSDK sharedSDK].usersManager userInfoWithID:BoxAPIUserIDMe
                                     requestBuilder:nil
                                            success:success
                                            failure:failure];
}

#pragma mark - Folder creation management

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
{
    BoxFolderBlock success = ^(BoxFolder *folder)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:YES],@"success",
                                           nil]];
        });
    };
    
    BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSString *errorMsg;
        switch (error.code)
        {
            case BoxSDKAPIErrorConflict:
            {
                errorMsg = NSLocalizedString(@"Name already exists",nil);
                break;
            }
                
            default:
            {
                errorMsg = [error localizedDescription];
                break;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           errorMsg,@"error",
                                           nil]];
        });

    };
    
    BoxFoldersRequestBuilder *builder = [[BoxFoldersRequestBuilder alloc] init];
    builder.name = folderName;
    if ([(NSString *)[folder.objectIds lastObject] isEqual:kRootID])
    {
        builder.parentID = BoxAPIFolderIDRoot;
    }
    else
    {
        builder.parentID = [folder.objectIds lastObject];
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [[BoxSDK sharedSDK].foldersManager createFolderWithRequestBuilder:builder success:success failure:failure];
}

#pragma mark - delete management

#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files
{
    deleteRequestsCount = 0;
    for (FileItem *file in files)
    {
        deleteRequestsCount ++;
        
        BoxSuccessfulDeleteBlock success = ^(NSString *deletedID)
        {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            deleteRequestsCount--;
            if (deleteRequestsCount == 0)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:YES],@"success",
                                                     nil]];
                });
            }
        };
        
        BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
        {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            deleteRequestsCount--;
            if (deleteRequestsCount == 0)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:YES],@"success",
                                                     nil]];
                });
            }
        };

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        if (file.isDir)
        {
            BoxFoldersRequestBuilder *builder = [[BoxFoldersRequestBuilder alloc] initWithRecursiveKey:YES];
            [[BoxSDK sharedSDK].foldersManager deleteFolderWithID:[file.objectIds lastObject]
                                                   requestBuilder:builder
                                                          success:success
                                                          failure:failure];
        }
        else
        {
            [[BoxSDK sharedSDK].filesManager deleteFileWithID:[file.objectIds lastObject]
                                               requestBuilder:nil
                                                      success:success
                                                      failure:failure];
        }
    }
}
#endif

#pragma mark - copy management

#ifndef APP_EXTENSION
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        copyRequestsCount --;
        if (copyRequestsCount == 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
    };
    
    BoxFolderBlock folderSuccess = ^(BoxFolder *folder)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        copyRequestsCount --;
        if (copyRequestsCount == 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
    };
    
    BoxFileBlock fileSuccess = ^(BoxFile *file)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        copyRequestsCount --;
        if (copyRequestsCount == 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
    };
    
    copyRequestsCount = 0;
    
    for (FileItem *file in files)
    {
        copyRequestsCount ++;
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        if (file.isDir)
        {
            
            BoxFoldersRequestBuilder *builder = [[BoxFoldersRequestBuilder alloc] init];
            if ([[destFolder.objectIds lastObject] isEqual:kRootID])
            {
                builder.parentID = BoxAPIFolderIDRoot;
            }
            else
            {
                builder.parentID = [destFolder.objectIds lastObject];
            }
            builder.name = file.name;
            
            [[BoxSDK sharedSDK].foldersManager copyFolderWithID:[file.objectIds lastObject]
                                                 requestBuilder:builder
                                                        success:folderSuccess
                                                        failure:failure];
        }
        else
        {
            BoxFilesRequestBuilder *builder = [[BoxFilesRequestBuilder alloc] init];
            if ([[destFolder.objectIds lastObject] isEqual:kRootID])
            {
                builder.parentID = BoxAPIFolderIDRoot;
            }
            else
            {
                builder.parentID = [destFolder.objectIds lastObject];
            }
            builder.name = file.name;
            
            [[BoxSDK sharedSDK].filesManager copyFileWithID:[file.objectIds lastObject]
                                             requestBuilder:builder
                                                    success:fileSuccess
                                                    failure:failure];
        }
    }
}
#endif

#pragma mark - Move management

#ifndef APP_EXTENSION
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    BoxFolderBlock folderSuccess = ^(BoxFolder *folder)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        moveRequestsCount --;
        if (moveRequestsCount == 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
    };

    BoxFileBlock fileSuccess = ^(BoxFile *file)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        moveRequestsCount --;
        if (moveRequestsCount == 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
    };
    
    BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        moveRequestsCount --;
        if (moveRequestsCount == 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
    };
    
    moveRequestsCount = 0;
    
    for (FileItem *file in files)
    {
        moveRequestsCount ++;
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        if (file.isDir)
        {
            
            BoxFoldersRequestBuilder *builder = [[BoxFoldersRequestBuilder alloc] init];
            if ([[destFolder.objectIds lastObject] isEqual:kRootID])
            {
                builder.parentID = BoxAPIFolderIDRoot;
            }
            else
            {
                builder.parentID = [destFolder.objectIds lastObject];
            }
            builder.name = file.name;
            
            [[BoxSDK sharedSDK].foldersManager editFolderWithID:[file.objectIds lastObject]
                                                 requestBuilder:builder
                                                        success:folderSuccess
                                                        failure:failure];
        }
        else
        {
            BoxFilesRequestBuilder *builder = [[BoxFilesRequestBuilder alloc] init];
            if ([[destFolder.objectIds lastObject] isEqual:kRootID])
            {
                builder.parentID = BoxAPIFolderIDRoot;
            }
            else
            {
                builder.parentID = [destFolder.objectIds lastObject];
            }
            builder.name = file.name;
            
            [[BoxSDK sharedSDK].filesManager editFileWithID:[file.objectIds lastObject]
                                             requestBuilder:builder
                                                    success:fileSuccess
                                                    failure:failure];
        }
    }
}
#endif

#pragma mark - Rename management

#ifndef APP_EXTENSION
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *errorMsg;
            switch (error.code)
            {
                case BoxSDKAPIErrorConflict:
                {
                    errorMsg = NSLocalizedString(@"Name already exists",nil);
                    break;
                }
                    
                default:
                {
                    errorMsg = [error localizedDescription];
                    break;
                }
            }

            [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],@"success",
                                     errorMsg,@"error",
                                     nil]];
        });
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    if (oldFile.isDir)
    {
        BoxFolderBlock success = ^(BoxFolder *folder)
        {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:YES],@"success",
                                         nil]];
            });
        };

        BoxFoldersRequestBuilder *builder = [[BoxFoldersRequestBuilder alloc] init];
        if ([[folder.objectIds lastObject] isEqual:kRootID])
        {
            builder.parentID = BoxAPIFolderIDRoot;
        }
        else
        {
            builder.parentID = [folder.objectIds lastObject];
        }
        builder.name = newName;
        
        [[BoxSDK sharedSDK].foldersManager editFolderWithID:[oldFile.objectIds lastObject]
                                               requestBuilder:builder
                                                      success:success
                                                      failure:failure];
    }
    else
    {
        BoxFileBlock success = ^(BoxFile *file)
        {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:YES],@"success",
                                         nil]];
            });
        };
        
        BoxFilesRequestBuilder *builder = [[BoxFilesRequestBuilder alloc] init];
        if ([[folder.objectIds lastObject] isEqual:kRootID])
        {
            builder.parentID = BoxAPIFolderIDRoot;
        }
        else
        {
            builder.parentID = [folder.objectIds lastObject];
        }
        builder.name = newName;
        
        [[BoxSDK sharedSDK].filesManager editFileWithID:[oldFile.objectIds lastObject]
                                         requestBuilder:builder
                                                success:success
                                                failure:failure];
    }
}
#endif

#pragma mark - Download management

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:localName append:NO];
    
    BoxDownloadSuccessBlock successBlock = ^(NSString *downloadedFileID, long long expectedContentLength)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
        });
    };
    
    BoxDownloadFailureBlock failureBlock = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (error.code != kCFURLErrorCancelled)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [error localizedDescription],@"error",
                                                   nil]];
            });
        }
    };
    
    BoxAPIDataProgressBlock progressBlock = ^(long long totalBytes, unsigned long long bytesReceived)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDownloadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithLongLong:bytesReceived],@"downloadedBytes",
                                               [NSNumber numberWithLongLong:totalBytes],@"totalBytes",
                                               [NSNumber numberWithFloat:(float)((float)bytesReceived/(float)totalBytes)],@"progress",
                                               nil]];
        });
    };

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.downloadOperation = [[BoxSDK sharedSDK].filesManager downloadFileWithID:[file.objectIds lastObject]
                                                                    outputStream:outputStream
                                                                  requestBuilder:nil
                                                                         success:successBlock
                                                                         failure:failureBlock
                                                                        progress:progressBlock];
}

- (void)cancelDownloadTask
{
    // Cancel request
    [self.downloadOperation cancel];
}

#pragma mark - Upload management

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
    BoxFileBlock success = ^(BoxFile *file)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:YES],@"success",
                                             nil]];
        });
    };
    
    BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (error.code != kCFURLErrorCancelled)
        {
            
            NSString *errorMsg;
            switch (error.code)
            {
                case BoxSDKAPIErrorConflict:
                {
                    errorMsg = NSLocalizedString(@"File already exists",nil);
                    break;
                }
                    
                default:
                {
                    errorMsg = [error localizedDescription];
                    break;
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 errorMsg,@"error",
                                                 nil]];
            });
        }
    };
    
    BoxAPIMultipartProgressBlock progress = ^(unsigned long long totalBytes, unsigned long long bytesSent)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMUploadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithLongLong:bytesSent],@"uploadedBytes",
                                                 [NSNumber numberWithLongLong:totalBytes],@"totalBytes",
                                                 [NSNumber numberWithFloat:(float)((float)bytesSent/(float)totalBytes)],@"progress",
                                                 nil]];
        });
    };

    BoxFilesRequestBuilder *builder = [[BoxFilesRequestBuilder alloc] init];
    builder.name = file.name;
    if ([[destFolder.objectIds lastObject] isEqual:kRootID])
    {
        builder.parentID = BoxAPIFolderIDRoot;
    }
    else
    {
        builder.parentID = [destFolder.objectIds lastObject];
    }
    
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:file.fullPath];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    FileItem *fileToReplace;
    if (overwrite)
    {
        // Look for existing file in upload folder
        for (FileItem *serverFile in filesArray)
        {
            if ([file.name isEqual:serverFile.name])
            {
                fileToReplace = serverFile;
                break;
            }
        }
    }
    
    if (overwrite && fileToReplace != nil)
    {
        self.uploadOperation = [[BoxSDK sharedSDK].filesManager overwriteFileWithID:[fileToReplace.objectIds lastObject]
                                                                        inputStream:inputStream
                                                                      contentLength:[file.fileSizeNumber longLongValue]
                                                                           MIMEType:nil
                                                                     requestBuilder:builder
                                                                            success:success
                                                                            failure:failure
                                                                           progress:progress];
    }
    else
    {
        self.uploadOperation = [[BoxSDK sharedSDK].filesManager uploadFileWithInputStream:inputStream
                                                                            contentLength:[file.fileSizeNumber longLongValue]
                                                                                 MIMEType:nil
                                                                           requestBuilder:builder
                                                                                  success:success
                                                                                  failure:failure
                                                                                 progress:progress];
    }
}

- (void)cancelUploadTask
{
    // Cancel request
    [self.uploadOperation cancel];
}

#pragma mark - search management

#ifndef APP_EXTENSION
- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder
{
    BoxCollectionBlock success = ^(BoxCollection *collection)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSMutableArray *filesOutputArray = nil;
        
        /* Build dictionary with items */
        filesOutputArray = [NSMutableArray arrayWithCapacity:collection.numberOfEntries];
        for (NSUInteger i = 0; i < collection.numberOfEntries; i++)
        {
            BoxItem *fileItem = (BoxItem *)[collection modelAtIndex:i];
            
            // File path
            NSMutableString *elementPath = [NSMutableString stringWithString:@"/"];
            for(NSUInteger pathIndex = 0; pathIndex < fileItem.pathCollection.numberOfEntries; pathIndex++)
            {
                BoxItem *element = (BoxItem *)[fileItem.pathCollection modelAtIndex:pathIndex];
                
                if ((![element.modelID isEqualToString:BoxAPIFolderIDRoot]) &&
                    ([element.type isEqualToString:BoxAPIItemTypeFolder]))
                {
                    [elementPath appendFormat:@"%@/",element.name];
                }
            }
            [elementPath appendString:fileItem.name];
            
            // Date
            NSNumber *fileDateNumber = [NSNumber numberWithDouble:[fileItem.modifiedAt timeIntervalSince1970]];
            
            NSMutableDictionary *dictItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [fileItem.type isEqualToString:BoxAPIItemTypeFolder]?@"1":@"0",@"isdir",
                                             fileItem.name,@"filename",
                                             elementPath,@"path",
                                             fileItem.modelID,@"id",
                                             @"",@"group",
                                             fileItem.createdBy.name,@"owner",
                                             [NSString stringForSize:[fileItem.size longLongValue]],@"filesize",
                                             fileItem.size,@"filesizenumber",
                                             fileDateNumber,@"date",
                                             [NSNumber numberWithBool:YES],@"writeaccess",
                                             nil];
            
            // File size
            if (fileItem.size)
            {
                [dictItem addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                    nil]];
            }
            
            // Date
            if (fileItem.modifiedAt)
            {
            }
            
            [filesOutputArray addObject:dictItem];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:YES],@"success",
                                             filesOutputArray,@"filesList",
                                             nil]];
        });
    };
    
    BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             [error localizedDescription],@"error",
                                             nil]];
        });
    };

    NSString *folderId;
    if ([[folder.objectIds lastObject] isEqual:kRootID])
    {
        folderId = BoxAPIFolderIDRoot;
    }
    else
    {
        folderId = [folder.objectIds lastObject];
    }

    BoxSearchRequestBuilder *builder = [[BoxSearchRequestBuilder alloc] initWithSearch:searchString
                                                                 queryStringParameters:@{
                                                                                         @"content_types" : @"name",
                                                                                         @"ancestor_folder_ids" : folderId,
                                                                                         @"limit" : @(200),
                                                                                         @"offset" : @(0)}];

    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [[BoxSDK sharedSDK].searchManager searchWithBuilder:builder
                                           successBlock:success
                                           failureBlock:failure];
}
#endif

#pragma mark - sharing management

#ifndef APP_EXTENSION
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password
{
    __block NSInteger filesCount = files.count;
    
    self.sharedLinks = [NSMutableString string];
    
    BoxFileBlock fileSuccess = ^(BoxFile *file)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        [self.sharedLinks appendFormat:@"%@ : %@\r\n",file.name, [file.sharedLink objectForKey:@"url"]];
        filesCount --;
        
        if (filesCount == 0)
        {
            if ([file.sharedLink objectForKey:@"unshared_at"] != [NSNull null])
            {
                [self.sharedLinks appendFormat:NSLocalizedString(@"\r\nLinks are valid until %@\r\n",nil),[file.sharedLink objectForKey:@"unshared_at"]];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                self.sharedLinks,@"shares",
                                                nil]];
            });
        }
    };
    
    BoxFolderBlock folderSuccess = ^(BoxFolder *folder)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        [self.sharedLinks appendFormat:@"%@ : %@\r\n",folder.name, [folder.sharedLink objectForKey:@"url"]];
        
        filesCount --;
        
        if (filesCount == 0)
        {
            if ([folder.sharedLink objectForKey:@"unshared_at"] != [NSNull null])
            {
                [self.sharedLinks appendFormat:NSLocalizedString(@"\r\nLinks are valid until %@\r\n",nil),[folder.sharedLink objectForKey:@"unshared_at"]];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                self.sharedLinks,@"shares",
                                                nil]];
            });
        }
    };

    BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSString *errorMsg;
        switch (error.code)
        {
            case BoxSDKAPIErrorBadRequest:
            {
                errorMsg = NSLocalizedString(@"Shared link expiration is available to items owned by paid users only.",nil);
                break;
            }
                
            default:
            {
                errorMsg = [error localizedDescription];
                break;
            }
        }

        [self.sharedLinks appendFormat:@"??? : %@\r\n", errorMsg];

        filesCount --;
        
        if (filesCount == 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                self.sharedLinks,@"shares",
                                                nil]];
            });
        }
    };
    
    BoxFilesRequestBuilder *filesBuilder = [[BoxFilesRequestBuilder alloc] init];
    filesBuilder.sharedLink = [[BoxSharedObjectBuilder alloc] init];
    filesBuilder.sharedLink.access = BoxAPISharedObjectAccessOpen;
    filesBuilder.sharedLink.canDownload = BoxAPISharedObjectPermissionStateEnabled;
    filesBuilder.sharedLink.canPreview = BoxAPISharedObjectPermissionStateEnabled;
    if (duration != 0)
    {
        NSDate *validityDate = [[NSDate alloc] initWithTimeIntervalSinceNow:duration];
        NSLog(@"date %@",validityDate);
        filesBuilder.sharedLink.unsharedAt = validityDate;
    }

    BoxFoldersRequestBuilder *folderBuilder = [[BoxFoldersRequestBuilder alloc] init];
    folderBuilder.sharedLink = [[BoxSharedObjectBuilder alloc] init];
    folderBuilder.sharedLink.access = BoxAPISharedObjectAccessOpen;
    folderBuilder.sharedLink.canDownload = BoxAPISharedObjectPermissionStateEnabled;
    folderBuilder.sharedLink.canPreview = BoxAPISharedObjectPermissionStateEnabled;
    if (duration != 0)
    {
        NSDate *validityDate = [[NSDate alloc] initWithTimeIntervalSinceNow:duration];
        folderBuilder.sharedLink.unsharedAt = validityDate;
    }
    

    for (FileItem *file in files)
    {
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        if (file.isDir)
        {
            [[BoxSDK sharedSDK].foldersManager editFolderWithID:[file.objectIds lastObject]
                                                 requestBuilder:folderBuilder
                                                        success:folderSuccess failure:failure];
        }
        else
        {
            [[BoxSDK sharedSDK].filesManager editFileWithID:[file.objectIds lastObject]
                                             requestBuilder:filesBuilder
                                                    success:fileSuccess
                                                    failure:failure];
        }
    }
}
#endif

#pragma mark - url management

#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file
{
    streamableURL = nil;
    
    BoxFileBlock fileSuccess = ^(BoxFile *file)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSString *shareId = [[file.sharedLink objectForKey:@"url"] substringFromIndex:[@"https://app.box.com/s/" length]];
        streamableURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://app.box.com/index.php?rm=box_download_shared_file&shared_name=%@&file_id=f_%@",shareId,file.modelID]];
    };
    
    BoxAPIJSONFailureBlock failure = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSDictionary *JSONDictionary)
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        streamableURL = [NSURL URLWithString:@"error"];
    };
    
    BoxFilesRequestBuilder *filesBuilder = [[BoxFilesRequestBuilder alloc] init];
    filesBuilder.sharedLink = [[BoxSharedObjectBuilder alloc] init];
    filesBuilder.sharedLink.access = BoxAPISharedObjectAccessOpen;
    filesBuilder.sharedLink.canDownload = BoxAPISharedObjectPermissionStateEnabled;
    filesBuilder.sharedLink.canPreview = BoxAPISharedObjectPermissionStateEnabled;
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [[BoxSDK sharedSDK].filesManager editFileWithID:[file.objectIds lastObject]
                                     requestBuilder:filesBuilder
                                            success:fileSuccess
                                            failure:failure];
    
    while (streamableURL == nil)
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    }
    
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.url = [NSURL URLWithString:@"TODO"];
    networkConnection.url = streamableURL;
    networkConnection.urlType = URLTYPE_HTTP;
    
  	return networkConnection;
}
#endif

#pragma mark - supported features

- (NSInteger)supportedFeaturesAtPath:(NSString *)path
{
    return (CMSupportedFeaturesMaskFileDelete      |
            CMSupportedFeaturesMaskFolderDelete    |
            CMSupportedFeaturesMaskFolderCreate    |
            CMSupportedFeaturesMaskFileRename      |
            CMSupportedFeaturesMaskFolderRename    |
            CMSupportedFeaturesMaskFileMove        |
            CMSupportedFeaturesMaskFolderMove      |
            CMSupportedFeaturesMaskFileCopy        |
            CMSupportedFeaturesMaskFolderCopy      |
            CMSupportedFeaturesMaskFileDownload    |
            CMSupportedFeaturesMaskDownloadCancel  |
            CMSupportedFeaturesMaskFileUpload      |
            CMSupportedFeaturesMaskUploadCancel    |
            CMSupportedFeaturesMaskSearch          |
            CMSupportedFeaturesMaskFileShare       |
            CMSupportedFeaturesMaskFolderShare     |
            CMSupportedFeaturesMaskQTPlayer        |
            CMSupportedFeaturesMaskVideoSeek       |
            CMSupportedFeaturesMaskAirPlay         |
            CMSupportedFeaturesMaskGoogleCast);
}

#ifndef APP_EXTENSION
- (NSInteger)supportedSharingFeatures
{
    return  CMSupportedSharingMaskValidityPeriod;
}

- (SHARING_VALIDITY_UNIT)shareValidityUnit
{
    return SHARING_VALIDITY_UNIT_DAY; // 1 day
}
#endif

#pragma mark - BoxSDK notification handlers

- (void)boxTokensDidRefresh:(NSNotification *)notification
{
    NSLog(@"boxTokensDidRefresh");
    BoxOAuth2Session *OAuth2Session = (BoxOAuth2Session *) notification.object;
    [self setRefreshTokenInKeychain:OAuth2Session.refreshToken];
}

- (void)setRefreshTokenInKeychain:(NSString *)refreshToken
{
    [SSKeychain setPassword:refreshToken
                 forService:self.userAccount.uuid
                    account:@"token"];
}

- (void)boxDidGetLoggedOut:(NSNotification *)notification
{
    NSLog(@"Received OAuth2 failed authenticated notification");
    NSString *oauth2Error = [[notification userInfo] valueForKey:BoxOAuth2AuthenticationErrorKey];
    NSLog(@"Authentication error  (%@)", oauth2Error);
}

- (void)boxTokenExpired:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMAction:[NSDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedString(@"Information",nil),@"title",
                                 NSLocalizedString(@"Session expired, please connect again in server's settings",nil),@"message",
                                 [NSNumber numberWithInteger:BROWSER_ACTION_QUIT_SERVER],@"action",
                                 nil]];
    });
}

#pragma mark - Memory management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
