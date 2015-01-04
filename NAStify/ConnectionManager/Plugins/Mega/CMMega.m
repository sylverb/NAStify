//
//  CMMega.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "CMMega.h"
#import "private.h"
#import "SSKeychain.h"

@implementation CMMega

#pragma mark - Server Info

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           [NSString stringWithFormat:NSLocalizedString(@"Server Type : %@",nil),@"Mega.co.nz"],
                           [NSString stringWithFormat:NSLocalizedString(@"User : %@",nil),self.megaSDK.myEmail],
                           nil];
    return serverInfo;
}

#pragma mark - login/logout management

- (BOOL)login
{
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    self.megaSDK = [[MEGASdk alloc] initWithAppKey:MEGA_KEY
                                         userAgent:[NSString defaultUserAgentString]
                                          basePath:basePath];
    
    if ([SSKeychain passwordForService:self.userAccount.uuid account:@"token"] != nil)
    {
        [self.megaSDK fastLoginWithSession:[SSKeychain passwordForService:self.userAccount.uuid account:@"token"] delegate:self];
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

- (BOOL)logout
{
    [self.megaSDK logoutWithDelegate:self];
    return YES;
}

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
    self.listPath = folder;
    [self.megaSDK fetchNodesWithDelegate:self];
}

#pragma mark - space info management

- (void)spaceInfoAtPath:(FileItem *)folder
{
    [self.megaSDK getAccountDetailsWithDelegate:self];
}

#pragma mark - Folder creation management

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder
{
    [self.megaSDK createFolderWithName:folderName
                                parent:[folder.objectIds lastObject]
                              delegate:self];
}

#pragma mark - delete management

#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files
{
    self.deleteFilesArray = files;
    self.deleteFileIndex = 0;
    self.deleteFileCancel = NO;
    
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
    
    [self.megaSDK removeNode:[file.objectIds lastObject]
                    delegate:self];
}

- (void)cancelDeleteTask
{
    self.deleteFileCancel = YES;
}
#endif

#pragma mark - Rename management

#ifndef APP_EXTENSION
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    [self.megaSDK renameNode:[oldFile.objectIds lastObject] newName:newName];
}
#endif

#pragma mark - Move management

#ifndef APP_EXTENSION
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    self.moveFilesArray = files;
    self.moveDestFolder = [destFolder.objectIds lastObject];
    self.moveFileIndex = 0;
    self.moveFileCancel = NO;
    
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
    FileItem *file = [self.moveFilesArray objectAtIndex:self.moveFileIndex];
    
    [self.megaSDK moveNode:[file.objectIds lastObject]
                 newParent:self.moveDestFolder
                  delegate:self];
}

- (void)cancelMoveTask
{
    self.moveFileCancel = YES;
}
#endif

#pragma mark - copy management

#ifndef APP_EXTENSION
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    self.cpyFilesArray = files;
    self.cpyDestFolder = [destFolder.objectIds lastObject];
    self.cpyFileIndex = 0;
    self.cpyFileCancel = NO;
    
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
    FileItem *file = [self.cpyFilesArray objectAtIndex:self.cpyFileIndex];

    [self.megaSDK copyNode:[file.objectIds lastObject]
                 newParent:self.cpyDestFolder
                  delegate:self];
}

- (void)cancelCopyTask
{
    self.cpyFileCancel = YES;
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
    FileItem *file = [self.shareFilesArray objectAtIndex:self.shareFileIndex];
    [self.sharedLinks appendFormat:@"%@ : ",file.name];
    
    [self.megaSDK exportNode:[file.objectIds lastObject]
                    delegate:self];
}

#endif

#pragma mark - Download management

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
    [self.megaSDK startDownloadNode:[file.objectIds lastObject]
                          localPath:localName
                           delegate:self];
}

- (void)cancelDownloadTask
{
    [self.megaSDK cancelTransfer:self.downloadTask
                        delegate:self];
}

#pragma mark - Download management

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
    [self.megaSDK startUploadToFileWithLocalPath:file.fullPath
                                          parent:[destFolder.objectIds lastObject]
                                        filename:file.name
                                        delegate:self];
}

- (void)cancelUploadTask
{
    [self.megaSDK cancelTransfer:self.uploadTask
                        delegate:self];
}

#pragma mark - supported features

- (NSInteger)supportedFeaturesAtPath:(NSString *)path
{
    NSInteger features = CMSupportedFeaturesMaskFolderCreate   |
                         CMSupportedFeaturesMaskFileDelete     |
                         CMSupportedFeaturesMaskFolderDelete   |
                         CMSupportedFeaturesMaskDeleteCancel   |
                         CMSupportedFeaturesMaskFileRename     |
                         CMSupportedFeaturesMaskFileMove       |
                         CMSupportedFeaturesMaskFolderMove     |
                         CMSupportedFeaturesMaskMoveCancel     |
                         CMSupportedFeaturesMaskFileCopy       |
                         CMSupportedFeaturesMaskFolderCopy     |
                         CMSupportedFeaturesMaskCopyCancel     |
                         CMSupportedFeaturesMaskFolderRename   |
                         CMSupportedFeaturesMaskFileShare      |
                         CMSupportedFeaturesMaskFolderShare    |
                         CMSupportedFeaturesMaskFileDownload   |
                         CMSupportedFeaturesMaskDownloadCancel |
                         CMSupportedFeaturesMaskFileUpload     |
                         CMSupportedFeaturesMaskUploadCancel;
    
    return features;
}

#pragma mark - MEGARequestDelegate

- (void)onRequestStart:(MEGASdk *)api request:(MEGARequest *)request
{
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
}

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error
{
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    
    switch (request.type)
    {
        case MEGARequestTypeLogin:
        {
            if (error.type == MEGAErrorTypeApiOk)
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
                                            NSLocalizedString(error.name,nil),@"error",
                                            nil]];
                });
            }
            break;
        }
        case MEGARequestTypeLogout:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMLogout:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:YES],@"success",
                                         nil]];
            });
            break;
        }
        case MEGARequestTypeFetchNodes:
        {
            MEGANodeList *nodes = nil;
            if ([self.listPath.path isEqual:@"/"])
            {
                nodes = [self.megaSDK childrenForParent:[self.megaSDK rootNode]];
                /* Send root id */
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMRootObject:[NSDictionary dictionaryWithObject:[self.megaSDK rootNode] forKey:@"rootId"]];
                });
            }
            else
            {
                nodes = [self.megaSDK childrenForParent:[self.listPath.objectIds lastObject]];
            }
            
            NSMutableArray *filesOutputArray = [NSMutableArray array];
            NSInteger index;
            for (index = 0; index < [nodes.size integerValue]; index++)
            {
                MEGANode *node = [nodes nodeAtIndex:index];
                NSMutableDictionary *dictItem;
                if (node.isFolder)
                {
                    dictItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithBool:YES],@"isdir",
                                node.name,@"filename",
                                node,@"id",
                                [NSNumber numberWithBool:YES],@"writeaccess",
                                [NSNumber numberWithDouble:[node.modificationTime timeIntervalSince1970]],@"date",
                                nil];
                    if ([self.listPath.path isEqual:@"/"])
                    {
                        [dictItem setObject:[self.megaSDK rootNode] forKey:@"rootId"];
                    }
                }
                else
                {
                    NSString *type = @"";
                    if ([[node.name componentsSeparatedByString:@"."] count] > 1)
                    {
                        type = [[node.name componentsSeparatedByString:@"."] lastObject];
                    }

                    dictItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithBool:NO],@"isdir",
                                node.name,@"filename",
                                node,@"id",
                                node.size,@"filesizenumber",
                                [NSNumber numberWithBool:YES],@"writeaccess",
                                [NSNumber numberWithDouble:[node.modificationTime timeIntervalSince1970]],@"date",
                                type,@"type",
                                nil];
                    
                    if ([self.listPath.path isEqual:@"/"])
                    {
                        [dictItem setObject:[self.megaSDK rootNode] forKey:@"rootId"];
                    }

                }
                [filesOutputArray addObject:dictItem];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:YES],@"success",
                                            self.listPath.path,@"path",
                                            filesOutputArray,@"filesList",
                                            nil]];
            });
            break;
        }
        case MEGARequestTypeAccountDetails:
        {
            if (error.type == MEGAErrorTypeApiOk)
            {
                long long freeSpace = [request.megaAccountDetails.storageMax longLongValue] - [request.megaAccountDetails.storageUsed longLongValue];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMSpaceInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                request.megaAccountDetails.storageMax,@"totalspace",
                                                [NSNumber numberWithLongLong:freeSpace],@"freespace",
                                                nil]];
                });
            }
            break;
        }
        case MEGARequestTypeCreateFolder:
        {
            if (error.type == MEGAErrorTypeApiOk)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES],@"success",
                                                   nil]];
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   NSLocalizedString(error.name,nil),@"error",
                                                   nil]];
                });
            }

            break;
        }
#ifndef APP_EXTENSION
        case MEGARequestTypeRename:
        {
            if (error.type == MEGAErrorTypeApiOk)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:YES],@"success",
                                             nil]];
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             NSLocalizedString(error.name,nil),@"error",
                                             nil]];
                });
            }
            break;
        }
        case MEGARequestTypeRemove:
        {
            if (error.type == MEGAErrorTypeApiOk)
            {
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
                    if (!self.deleteFileCancel)
                    {
                        // Delete next file
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self deleteNextFile];
                        });
                    }
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   NSLocalizedString(error.name,nil),@"error",
                                                   nil]];
                });
            }
            break;
        }
        case MEGARequestTypeMove:
        {
            if (error.type == MEGAErrorTypeApiOk)
            {
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
                    if (!self.moveFileCancel)
                    {
                        // Move next file
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self moveNextFile];
                        });
                    }
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   NSLocalizedString(error.name,nil),@"error",
                                                   nil]];
                });
            }
            break;
        }
        case MEGARequestTypeCopy:
        {
            if (error.type == MEGAErrorTypeApiOk)
            {
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
                    if (!self.cpyFileCancel)
                    {
                        // Move next file
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self cpyNextFile];
                        });
                    }
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   NSLocalizedString(error.name,nil),@"error",
                                                   nil]];
                });
            }
            break;
        }
        case MEGARequestTypeExport:
        {
            if (error.type == MEGAErrorTypeApiOk)
            {
                [self.sharedLinks appendFormat:@"%@\r\n",request.link];
            }
            else
            {
                [self.sharedLinks appendFormat:NSLocalizedString(@"error : %@\r\n",nil),error.name];
            }
            
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
            break;
        }
#endif
        case MEGARequestTypeCancelTransfer:
        {
            // Nothing to do here
            break;
        }
        default:
        {
            if (error.type == MEGAErrorTypeApiOk)
            {
                NSLog(@"Unhandled request %ld (OK)",request.type);
            }
            else
            {
                NSLog(@"Unhandled request %ld (Error %@)",request.type,error.name);
            }
            break;
        }
    }
}

- (void)onRequestTemporaryError:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error
{
    NSLog(@"onRequestTemporaryError %@",error.name);
}

#pragma mark - MEGATransferDelegate

- (void)onTransferStart:(MEGASdk *)api transfer:(MEGATransfer *)transfer
{
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    // Save transfert to be able to cancel it
    if (transfer.type == MEGATransferTypeDownload)
    {
        self.downloadTask = transfer;
    }
    else if (transfer.type == MEGATransferTypeUpload)
    {
        self.uploadTask = transfer;
    }
}

- (void)onTransferUpdate:(MEGASdk *)api transfer:(MEGATransfer *)transfer
{
    switch (transfer.type)
    {
        case MEGATransferTypeUpload:
        {
            //NSString *localFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[transfer fileName]];
            float progress = [transfer.transferredBytes floatValue]/[transfer.totalBytes floatValue];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [transfer transferredBytes],@"uploadedBytes",
                                                 [transfer totalBytes],@"totalBytes",
                                                 [NSNumber numberWithFloat:progress],@"progress",
                                                 nil]];
            });
            break;
        }
        case MEGATransferTypeDownload:
        {
            float progress = [transfer.transferredBytes floatValue]/[transfer.totalBytes floatValue];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDownloadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [transfer transferredBytes],@"downloadedBytes",
                                                   [transfer totalBytes],@"totalBytes",
                                                   [NSNumber numberWithFloat:progress],@"progress",
                                                   nil]];
            });
        }
        default:
            break;
    }
}

- (void)onTransferFinish:(MEGASdk *)api transfer:(MEGATransfer *)transfer error:(MEGAError *)error
{
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    
    NSLog(@"onTransferFinish error %ld",error.type);
    switch (transfer.type)
    {
        case MEGATransferTypeUpload:
        {
            //NSString *localFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[transfer fileName]];
            if (error.type == MEGAErrorTypeApiOk)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:YES],@"success",
                                                     nil]];
                });
            }
            else if (error.type != MEGAErrorTypeApiEIncomplete)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     error.name,@"error",
                                                     nil]];
                });
            }
            break;
        }
        case MEGATransferTypeDownload:
        {
            if (error.type == MEGAErrorTypeApiOk)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:YES],@"success",
                                                       nil]];
                });
            }
            else if (error.type != MEGAErrorTypeApiEIncomplete)
            {
                //FIXME: Delete incomplete file
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       error.name,@"error",
                                                       nil]];
                });
            }
        }
        default:
            break;
    }
}

-(void)onTransferTemporaryError:(MEGASdk *)api transfer:(MEGATransfer *)transfer error:(MEGAError *)error
{
}

#pragma mark - Memory management

- (void)dealloc
{
    self.megaSDK = nil;
}
@end
