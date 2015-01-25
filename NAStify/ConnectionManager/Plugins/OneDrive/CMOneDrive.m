//
//  CMOneDrive.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//
//  SDK : https://github.com/liveservices/LiveSDK-for-iOS
//  Documentation : http://msdn.microsoft.com/library/dn631816.aspx
//

#import "CMOneDrive.h"
#import "SSKeychain.h"
#import "private.h"

#import "ISO8601DateFormatter.h"

@implementation CMOneDrive

#pragma mark - Server Info

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           [NSString stringWithFormat:NSLocalizedString(@"Server Name : %@",nil),@"Microsoft OneDrive"],
                           [NSString stringWithFormat:NSLocalizedString(@"Account : %@",nil),self.userAccount.accountName],
                           nil];
    return serverInfo;
}

#pragma mark - Login management

- (BOOL)login
{
    self.liveClient = [[LiveConnectClient alloc] initManuallyWithClientId:ONEDRIVE_CLIENT_ID
                                                                   scopes:[NSArray arrayWithObjects:
                                                                           @"wl.signin",
                                                                           @"wl.skydrive_update",
                                                                           @"wl.offline_access", nil]
                                                                 delegate:self];
    
    if ([SSKeychain passwordForService:self.userAccount.uuid account:@"token"] != nil)
    {
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.liveClient refreshSessionWithDelegate:self
                                       refreshToken:[SSKeychain passwordForService:self.userAccount.uuid account:@"token"]
                                          userState:@"status"];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO],@"success",
                                    NSLocalizedString(@"Token error, please reconnect in server's settings", nil),@"error",
                                    nil]];
        });
    }
    
    return YES;
}

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
    self.path = folder.path;
    
    NSString *path = nil;
    if ([[folder.objectIds lastObject] isEqualToString:kRootID])
    {
        path = @"me/skydrive/files";
    }
    else
    {
        path = [NSString stringWithFormat:@"%@/files",[folder.objectIds lastObject]];
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.fileListOperation = [self.liveClient getWithPath:path
                                                 delegate:self
                                                userState:@"fileList"];
}

#pragma mark - space info management

- (void)spaceInfoAtPath:(FileItem *)folder
{
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.spaceInfoOperation = [self.liveClient getWithPath:@"me/skydrive/quota"
                                                  delegate:self
                                                 userState:@"spaceInfo"];
}

#pragma mark - Folder creation management

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder
{
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

    NSDictionary * newFolder = [NSDictionary dictionaryWithObjectsAndKeys:
                                 folderName,@"name",
                                 @"folder",@"type",
                                 nil];
    
    self.createFolderOperation = [self.liveClient postWithPath:[folder.objectIds lastObject]
                                                      dictBody:newFolder
                                                      delegate:self
                                                     userState:@"createFolder"];
}

#pragma mark - delete management

#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files
{
    self.deleteFilesArray = files;
    self.deleteFileIndex = 0;
    
    // Send initial progress
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMDeleteProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithFloat:0.0f],@"progress",
                                         nil]];
    });
    
    [self deleteNextFile];
}

- (void)deleteNextFile
{
    FileItem *file = [self.deleteFilesArray objectAtIndex:self.deleteFileIndex];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.deleteOperation = [self.liveClient deleteWithPath:[file.objectIds lastObject]
                                                  delegate:self
                                                 userState:@"delete"];
}

- (void)cancelDeleteTask
{
    [self.deleteOperation cancel];
    self.deleteFilesArray = nil;
}
#endif

#pragma mark - Rename management

#ifndef APP_EXTENSION
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    NSDictionary * updatedFile = [NSDictionary dictionaryWithObjectsAndKeys:
                                  newName,@"name",
                                  nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.renameOperation = [self.liveClient putWithPath:[oldFile.objectIds lastObject]
                                               dictBody:updatedFile
                                               delegate:self
                                              userState:@"rename"];
}
#endif

#pragma mark - Move management

#ifndef APP_EXTENSION
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    self.moveFilesArray = files;
    self.moveDestFolder = [destFolder.objectIds lastObject];
    self.moveOverwrite = overwrite;
    self.moveFileIndex = 0;
    
    // Send initial progress
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMMoveProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSNumber numberWithFloat:0.0f],@"progress",
                                       nil]];
    });
    
    [self moveNextFile];
}

- (void)moveNextFile
{
    FileItem *file =[self.moveFilesArray objectAtIndex:self.moveFileIndex];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.moveOperation = [self.liveClient moveFromPath:[file.objectIds lastObject]
                                         toDestination:self.moveDestFolder
                                              delegate:self
                                             userState:@"move"];
}

- (void)cancelMoveTask
{
    self.moveFilesArray = nil;
    self.moveDestFolder = nil;
    [self.moveOperation cancel];
}
#endif

#pragma mark - copy management

#ifndef APP_EXTENSION
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    self.cpyFilesArray = files;
    self.cpyDestFolder = [destFolder.objectIds lastObject];
    self.cpyOverwrite = overwrite;
    self.cpyFileIndex = 0;
    
    // Send initial progress
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMCopyProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSNumber numberWithFloat:0.0f],@"progress",
                                       nil]];
    });
    
    [self cpyNextFile];
}

- (void)cpyNextFile
{
    FileItem *file =[self.cpyFilesArray objectAtIndex:self.cpyFileIndex];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.cpyOperation = [self.liveClient copyFromPath:[file.objectIds lastObject]
                                        toDestination:self.cpyDestFolder
                                             delegate:self
                                            userState:@"copy"];
}

- (void)cancelCopyTask
{
    self.cpyFilesArray = nil;
    self.cpyDestFolder = nil;

    [self.cpyOperation cancel];
}
#endif

#pragma mark - sharing management

#ifndef APP_EXTENSION
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password
{
    self.sharedLinks = [[NSMutableString alloc] init];
    self.shareFilesArray = files;
    self.shareFileIndex = 0;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMShareProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithFloat:0.0f],@"progress",
                                        nil]];
    });
    
    [self shareNextFile];
}

- (void)shareNextFile
{
    FileItem *file =[self.self.shareFilesArray objectAtIndex:self.shareFileIndex];
    
    [self.sharedLinks appendFormat:@"%@ : ",file.name];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.shareOperation = [self.liveClient getWithPath:[[file.objectIds lastObject] stringByAppendingString:@"/shared_read_link"]
                                              delegate:self
                                             userState:@"share"];
}

#endif

#pragma mark - Download management

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
    self.destPath = localName;
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.downloadOperation = [self.liveClient downloadFromPath:[[file.objectIds lastObject] stringByAppendingString:@"/content"]
                                               destinationPath:localName
                                                      delegate:self
                                                     userState:@"downloadFile"];
}

- (void) liveDownloadOperationProgressed:(LiveOperationProgress *)progress
                               operation:(LiveDownloadOperation *)operation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMDownloadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithUnsignedInteger:progress.bytesTransferred],@"downloadedBytes",
                                               [NSNumber numberWithUnsignedInteger:progress.totalBytes],@"totalBytes",
                                               [NSNumber numberWithDouble:progress.progressPercentage],@"progress",
                                               nil]];
    });
}

- (void)cancelDownloadTask
{
    [self.downloadOperation cancel];
}

#pragma mark - upload management

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
    NSInputStream *fileStream = [[NSInputStream alloc] initWithFileAtPath:file.fullPath];
    
    LiveUploadOverwriteOption liveOverwrite;
    if (overwrite)
    {
        liveOverwrite = LiveUploadOverwrite;
    }
    else
    {
        liveOverwrite = LiveUploadDoNotOverwrite;
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.uploadOperation = [self.liveClient uploadToPath:[destFolder.objectIds lastObject]
                                           fileName:file.name
                                        inputStream:fileStream
                                          overwrite:liveOverwrite
                                           delegate:self
                                          userState:@"uploadFile"];
}

- (void) liveUploadOperationProgressed:(LiveOperationProgress *)progress
                             operation:(LiveOperation *)operation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMUploadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithUnsignedInteger:progress.bytesTransferred],@"uploadedBytes",
                                         [NSNumber numberWithUnsignedInteger:progress.totalBytes],@"totalBytes",
                                         [NSNumber numberWithDouble:progress.progressPercentage],@"progress",
                                         nil]];
    });
}

- (void)cancelUploadTask
{
    [self.uploadOperation cancel];
}

#pragma mark - url management

- (NetworkConnection *)urlForFile:(FileItem *)file
{
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.url = [NSURL URLWithString:file.downloadUrl];
    networkConnection.urlType = URLTYPE_HTTP;
    
    return networkConnection;
}

#pragma mark - supported features

- (long long)supportedFeaturesAtPath:(NSString *)path
{
    long long features = CMSupportedFeaturesMaskFileDelete     |
                         CMSupportedFeaturesMaskFolderDelete   |
                         CMSupportedFeaturesMaskFileRename     |
                         CMSupportedFeaturesMaskFileMove       |
                         CMSupportedFeaturesMaskFolderMove     |
                         CMSupportedFeaturesMaskFileCopy       |
                         CMSupportedFeaturesMaskFolderRename   |
                         CMSupportedFeaturesMaskFileShare      |
                         CMSupportedFeaturesMaskFolderShare    |
                         CMSupportedFeaturesMaskVLCPlayer      |
                         CMSupportedFeaturesMaskQTPlayer       |
                         CMSupportedFeaturesMaskGoogleCast     |
                         CMSupportedFeaturesMaskCacheImage;
    return features;
}

#pragma mark - LiveOperationDelegate

- (void) liveOperationSucceeded:(LiveOperation *)operation
{
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

    if ([operation.userState isEqual:@"fileList"])
    {
        NSDictionary *result = operation.result;
        NSArray *filesArray = [result objectForKey:@"data"];
        NSMutableArray *filesOutputArray = nil;
        /* Send root id if needed */
        if ([self.path isEqual:@"/"])
        {
            NSString *parentId;
            if (filesArray.count > 0)
            {
                NSDictionary *firstFile = [filesArray firstObject];
                parentId = [firstFile objectForKey:@"parent_id"];
            }
            else
            {
                parentId = @"me/skydrive";
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMRootObject:[NSDictionary dictionaryWithObject:parentId forKey:@"rootId"]];
            });
        }

        /* Build dictionary with items */
        filesOutputArray = [NSMutableArray arrayWithCapacity:[filesArray count]];
        for (NSDictionary *file in filesArray)
        {
            {
                NSString *name = [file objectForKey:@"name"];
                BOOL isDir = NO;
                if (([[file objectForKey:@"type"] isEqualToString:@"folder"]) ||
                    ([[file objectForKey:@"type"] isEqualToString:@"album"]))
                {
                    isDir = YES;
                }
                ISO8601DateFormatter *dateFormatter = [[ISO8601DateFormatter alloc] init];
                NSDate *date = [dateFormatter dateFromString:[file objectForKey:@"updated_time"]];

                NSMutableDictionary *dictItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:isDir],@"isdir",
                                                 name,@"filename",
                                                 [file objectForKey:@"id"],@"id",
                                                 [file objectForKey:@"size"],@"filesizenumber",
                                                 [NSNumber numberWithBool:YES],@"writeaccess",
                                                 [NSNumber numberWithLong:[date timeIntervalSince1970]],@"date",
                                                 nil];
                if ([[file objectForKey:@"from"] objectForKey:@"name"])
                {
                    [dictItem setObject:[[file objectForKey:@"from"] objectForKey:@"name"] forKey:@"owner"];
                }
                if (!isDir)
                {
                    NSArray *components = [name componentsSeparatedByString:@"."];
                    if (components.count > 1)
                    {
                        NSString *type = [components lastObject];
                        [dictItem setObject:type forKey:@"type"];
                    }
                    [dictItem setObject:[file objectForKey:@"source"] forKey:@"url"];
                }
                [filesOutputArray addObject:dictItem];
            }
        }
        
        self.fileListOperation = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES],@"success",
                                        self.path,@"path",
                                        filesOutputArray,@"filesList",
                                        nil]];
        });
    }
    else if ([operation.userState isEqual:@"spaceInfo"])
    {
        self.spaceInfoOperation = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMSpaceInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES],@"success",
                                        [operation.result objectForKey:@"quota"],@"totalspace",
                                        [operation.result objectForKey:@"available"],@"freespace",
                                        nil]];
        });
    }
    else if ([operation.userState isEqual:@"createFolder"])
    {
        self.createFolderOperation = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:YES],@"success",
                                           nil]];
        });
    }
#ifndef APP_EXTENSION
    else if ([operation.userState isEqual:@"delete"])
    {
        self.deleteOperation = nil;
        
        self.deleteFileIndex++;
        
        // Send progress
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDeleteProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithFloat:(float)self.deleteFileIndex/(float)self.deleteFilesArray.count],@"progress",
                                             [NSString stringWithFormat:@"%lu/%lu done",(long)self.deleteFileIndex,(long)self.deleteFilesArray.count],@"info",
                                             nil]];
        });

        if (self.deleteFileIndex == self.deleteFilesArray.count)
        {
            // Last file deleted
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:YES],@"success",
                                                 nil]];
            });
        }
        else
        {
            // Delete next file
            dispatch_async(dispatch_get_main_queue(), ^{
                [self deleteNextFile];
            });
        }
    }
    else if ([operation.userState isEqual:@"rename"])
    {
        self.renameOperation = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:YES],@"success",
                                     nil]];
        });
    }
    else if ([operation.userState isEqual:@"move"])
    {
        self.moveOperation = nil;
        
        self.moveFileIndex++;
        
        // Send progress
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMMoveProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithFloat:(float)self.moveFileIndex/(float)self.moveFilesArray.count],@"progress",
                                           [NSString stringWithFormat:@"%lu/%lu done",(long)self.moveFileIndex,(long)self.moveFilesArray.count],@"info",
                                           nil]];
        });
        
        if (self.moveFileIndex == self.moveFilesArray.count)
        {
            // Last file moved
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
        else
        {
            // Move next file
            dispatch_async(dispatch_get_main_queue(), ^{
                [self moveNextFile];
            });
        }
    }
    else if ([operation.userState isEqual:@"copy"])
    {
        self.cpyOperation = nil;
        self.cpyFileIndex++;
        
        // Send progress
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCopyProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithFloat:(float)self.cpyFileIndex/(float)self.cpyFilesArray.count],@"progress",
                                           [NSString stringWithFormat:@"%lu/%lu done",(long)self.cpyFileIndex,(long)self.cpyFilesArray.count],@"info",
                                           nil]];
        });
        
        if (self.cpyFileIndex == self.cpyFilesArray.count)
        {
            // Last file copied
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
        else
        {
            // Copy next file
            dispatch_async(dispatch_get_main_queue(), ^{
                [self cpyNextFile];
            });
        }
    }
    else if ([operation.userState isEqual:@"share"])
    {
        [self.sharedLinks appendFormat:@"%@\r\n",[operation.result objectForKey:@"link"]];
        
        self.shareOperation = nil;
        self.shareFileIndex++;

        // Send progress
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMShareProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithFloat:(float)self.shareFileIndex/(float)self.shareFilesArray.count],@"progress",
                                           [NSString stringWithFormat:@"%lu/%lu done",(long)self.shareFileIndex,(long)self.shareFilesArray.count],@"info",
                                           nil]];
        });
        
        if (self.shareFileIndex == self.shareFilesArray.count)
        {
            // Last file shared
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                self.sharedLinks,@"shares",
                                                nil]];
            });
        }
        else
        {
            // Share next file
            dispatch_async(dispatch_get_main_queue(), ^{
                [self shareNextFile];
            });
        }
    }
#endif
    
    else if ([operation.userState isEqual:@"downloadFile"])
    {
        self.downloadOperation = nil;
        self.destPath = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
        });
    }
    if ([operation.userState isEqual:@"uploadFile"])
    {
        self.uploadOperation = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:YES],@"success",
                                             nil]];
        });
    }
}

- (void) liveOperationFailed:(NSError *)error operation:(LiveOperation *)operation
{
    // Handle error here.
    NSString *errorString;
    BOOL requestCancelled;
    
    if ([[error.userInfo objectForKey:@"error"] isEqual:@"request_canceled"])
    {
        requestCancelled = YES;
    }
    else
    {
        requestCancelled = NO;
    }

    if ([error.userInfo objectForKey:@"message"])
    {
        errorString = NSLocalizedString([error.userInfo objectForKey:@"message"],nil);
    }
    else
    {
        errorString = [error localizedDescription];
    }
    
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    if ([operation.userState isEqual:@"fileList"])
    {
        self.fileListOperation = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        self.path,@"path",
                                        errorString,@"error",
                                        nil]];
        });
    }
    else if ([operation.userState isEqual:@"spaceInfo"])
    {
        // Unable to get free space, nothing special to do here
        self.spaceInfoOperation = nil;
    }
    else if ([operation.userState isEqual:@"createFolder"])
    {
        self.createFolderOperation = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           errorString,@"error",
                                           nil]];
        });
    }
    
#ifndef APP_EXTENSION
    else if ([operation.userState isEqual:@"delete"])
    {
        self.deleteOperation = nil;
        self.deleteFilesArray = nil;
        if (!requestCancelled)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 errorString,@"error",
                                                 nil]];
            });
        }
    }
    else if ([operation.userState isEqual:@"rename"])
    {
        self.renameOperation = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],@"success",
                                     errorString,@"error",
                                     nil]];
        });
    }
    else if ([operation.userState isEqual:@"move"])
    {
        self.moveOperation = nil;
        self.moveFilesArray = nil;
        self.moveDestFolder = nil;
        if (!requestCancelled)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               errorString,@"error",
                                               nil]];
            });
        }
    }
    else if ([operation.userState isEqual:@"copy"])
    {
        self.cpyOperation = nil;
        self.cpyFilesArray = nil;
        self.cpyDestFolder = nil;
        if (!requestCancelled)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               errorString,@"error",
                                               nil]];
            });
        }
    }
    else if ([operation.userState isEqual:@"share"])
    {
        self.shareOperation = nil;
        if (!requestCancelled)
        {
            [self.sharedLinks appendFormat:@"%@\r\n",errorString];
            self.shareFileIndex++;
            
            // Send progress
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithFloat:(float)self.shareFileIndex/(float)self.shareFilesArray.count],@"progress",
                                                [NSString stringWithFormat:@"%lu/%lu done",(long)self.shareFileIndex,(long)self.shareFilesArray.count],@"info",
                                                nil]];
            });
            
            if (self.shareFileIndex == self.shareFilesArray.count)
            {
                // Last file shared
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                    [NSNumber numberWithBool:YES],@"success",
                                                    self.sharedLinks,@"shares",
                                                    nil]];
                });
            }
            else
            {
                // Share next file
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self shareNextFile];
                });
            }
        }
    }
#endif

    else if ([operation.userState isEqual:@"downloadFile"])
    {
        self.downloadOperation = nil;
        if (!requestCancelled)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   errorString,@"error",
                                                   nil]];
            });
        }
        // Delete partially downloaded file
        [[NSFileManager defaultManager] removeItemAtPath:self.destPath error:NULL];
        self.destPath = nil;
    }
    else if ([operation.userState isEqual:@"uploadFile"])
    {
        self.uploadOperation = nil;
        if (!requestCancelled)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 errorString,@"error",
                                                 nil]];
            });
        }
    }
}

#pragma mark - LiveAuthDelegate

- (void)authCompleted:(LiveConnectSessionStatus)status
              session:(LiveConnectSession *)session
            userState:(id)userState
{
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    
    if (status == LiveAuthConnected)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    nil]];
        });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO],@"success",
                                    NSLocalizedString(@"Token error", nil),@"error",
                                    nil]];
        });
    }
}

- (void)authFailed:(NSError *) error
         userState:(id)userState
{
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithBool:NO],@"success",
                                [error localizedDescription],@"error",
                                nil]];
    });
}

@end
