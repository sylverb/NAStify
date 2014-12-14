//
//  CMGoogleDrive.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//
//FIXME: handle cancel for different actions
//FIXME: handle multiple files for copy/move/delete/share

#import "CMGoogleDrive.h"
#import "SBNetworkActivityIndicator.h"
#import "NSStringAdditions.h"
#import "private.h"

@implementation CMGoogleDrive

#pragma mark - Server Info
- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           NSLocalizedString(@"Server type : Google Drive",nil),
                           [NSString stringWithFormat:NSLocalizedString(@"User : %@", nil), self.authentication.userEmail],
                           [NSString stringWithFormat:NSLocalizedString(@"Used quota : %@", nil), self.usedQuota],
                           nil];
    return serverInfo;
}

#pragma mark - login/logout management

- (BOOL)login
{
    // Check for authorization.
    self.authentication =
    [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:self.userAccount.uuid
                                                          clientID:GOOGLEDRIVE_CLIENT_ID
                                                      clientSecret:GOOGLEDRIVE_CLIENT_SECRET];
    if ([self.authentication canAuthorize])
    {
        self.serviceDrive = [[GTLServiceDrive alloc] init];
        [self.serviceDrive setAuthorizer:self.authentication];
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
                                    NSLocalizedString(@"You need to authorize in server settings", nil),@"error",
                                    nil]];
        });
    }
    return YES;
}

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
    query.maxResults = INT_MAX;
    
    // Filter out trashed files and files in other folders
    NSString* search = @"trashed=false";
    NSString *parent;
    if ([[folder.objectIds lastObject] isEqualToString:kRootID])
    {
        parent = @"root";
    }
    else
    {
        parent = [folder.objectIds lastObject];
    }
    
    search = [search stringByAppendingFormat:@" and '%@' in parents", parent];
    query.q = search;

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

//    GTLServiceTicket *queryTicket =
    [self.serviceDrive executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                              GTLDriveFileList *files,
                                                              NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

        if (error == nil)
        {
            NSMutableArray *filesOutputArray = [NSMutableArray array];
            for (GTLDriveFile *file in files.items)
            {
//                NSLog(@"%@",file);
                NSDictionary *dictItem;
                if ([file.mimeType isEqualToString:@"application/vnd.google-apps.folder"])
                {
                    dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithBool:YES],@"isdir",
                                file.title,@"filename",
                                file.identifier,@"id",
                                [NSNumber numberWithBool:YES],@"writeaccess",
                                [NSNumber numberWithDouble:[file.modifiedDate.date timeIntervalSince1970]],@"date",
                                file.webContentLink,@"url",
                                nil];

                }
                else
                {
                    dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithBool:NO],@"isdir",
                                file.title,@"filename",
                                file.identifier,@"id",
                                file.fileSize,@"filesizenumber",
                                [NSNumber numberWithBool:YES],@"writeaccess",
                                [NSNumber numberWithDouble:[file.modifiedDate.date timeIntervalSince1970]],@"date",
                                file.fileExtension,@"type",
                                file.downloadUrl,@"url",
                                nil];
                }
                [filesOutputArray addObject:dictItem];
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
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            folder.path,@"path",
                                            error.localizedDescription,@"error",
                                            nil]];
            });
        }
    }];
}

#pragma mark - space info management

- (void)spaceInfoAtPath:(FileItem *)folder
{
    GTLQueryDrive *query = [GTLQueryDrive queryForAboutGet];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.serviceDrive executeQuery:query
        completionHandler:^(GTLServiceTicket *ticket, GTLDriveAbout *about,
                            NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            if (error == nil)
            {
                long long used_ll = 0;
                for (GTLDriveAboutQuotaBytesByServiceItem *service in about.quotaBytesByService)
                {
                    used_ll+=[service.bytesUsed longLongValue];
                }
                NSNumber *total = [NSNumber numberWithLongLong:[about.quotaBytesTotal longLongValue]];
                long long free_ll = [about.quotaBytesTotal longLongValue] - used_ll;
                NSNumber *free = [NSNumber numberWithLongLong:free_ll];
                
                self.usedQuota = [NSString stringWithFormat:@"%lld MB",[about.quotaBytesUsed longLongValue]/(1024*1024)];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMSpaceInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                total,@"totalspace",
                                                free,@"freespace",
                                                nil]];
                });

            }
        }];
}

#pragma mark - Folder creation management

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
{
    GTLDriveFile *folderObj = [GTLDriveFile object];
    folderObj.title = folderName;
    folderObj.mimeType = @"application/vnd.google-apps.folder";
    
    // To create a folder in a specific parent folder, specify the identifier
    // of the parent:
    // _resourceId is the identifier from the parent folder
    NSString *ressourceID = [folder.objectIds lastObject];
    if (ressourceID.length && ![ressourceID isEqualToString:kRootID])
    {
        GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
        parentRef.identifier = ressourceID;
        folderObj.parents = [NSArray arrayWithObject:parentRef];
    }
    
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:folderObj uploadParameters:nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.serviceDrive executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                              GTLDriveFile *updatedFile,
                                                              NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (error == nil)
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
                                               [error localizedDescription],@"error",
                                               nil]];
            });
        }
    }];
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
    
    GTLQueryDrive *deleteQuery =[GTLQueryDrive queryForFilesDeleteWithFileId:[file.objectIds lastObject]];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.deleteTicket =
        [self.serviceDrive executeQuery:deleteQuery completionHandler:^(GTLServiceTicket *ticket,
                                                                        id object,
                                                                        NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (error == nil)
        {
            self.deleteFileIndex++;
            
            // Send progress
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithFloat:(float)self.deleteFileIndex/(float)self.deleteFilesArray.count],@"progress",
                                               [NSString stringWithFormat:@"%lu/%lu done",self.deleteFileIndex,(unsigned long)self.deleteFilesArray.count],@"info",
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
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 error.localizedDescription,@"error",
                                                 nil]];
            });
        }
    }];
}

- (void)cancelDeleteTask
{
    [self.deleteTicket cancelTicket];
    self.deleteFilesArray = nil;
    
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
}
#endif

#pragma mark - Rename management

#ifndef APP_EXTENSION
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    GTLDriveFile *file = [GTLDriveFile object];
    file.title = newName;
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesPatchWithObject:file
                                                                fileId:[oldFile.objectIds lastObject]];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.serviceDrive executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                              GTLDriveFile *updatedFile,
                                                              NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
            if (error == nil)
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
                                             [error localizedDescription],@"error",
                                             nil]];
                });
            }
        }];
}
#endif

#pragma mark - Move management

#ifndef APP_EXTENSION
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    self.moveFilesArray = files;
    self.moveFileIndex = 0;
    self.moveDestFolder = destFolder;
    self.moveOverwrite = overwrite;
    
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
    //FIXME : handle overwrite option
    FileItem *file = [self.moveFilesArray objectAtIndex:self.moveFileIndex];
    
    // File object used for the move.
    GTLDriveParentReference *reference = [[GTLDriveParentReference alloc] init];
    if ([[self.moveDestFolder.objectIds lastObject] isEqualToString:kRootID])
    {
        reference.identifier = @"root";
        reference.isRoot = [NSNumber numberWithBool:TRUE];
    }
    else
    {
        reference.identifier = [self.moveDestFolder.objectIds lastObject];
        reference.isRoot = [NSNumber numberWithBool:FALSE];
    }
    
    GTLQueryDrive *query = [GTLQueryDrive queryForParentsInsertWithObject:reference fileId:[file.objectIds lastObject]];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.moveTicket =
    [self.serviceDrive executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                              GTLDriveFile *updatedFile,
                                                              NSError *error) {
        if (error == nil)
        {
            // Delete old parent
            NSString *folderID;
            if ([[file.objectIds objectAtIndex:(file.objectIds.count - 2)] isEqualToString:kRootID])
            {
                folderID = @"root";
            }
            else
            {
                folderID = [file.objectIds objectAtIndex:(file.objectIds.count - 2)];
            }
            GTLQueryDrive *query = [GTLQueryDrive queryForParentsDeleteWithFileId:[file.objectIds lastObject] parentId:folderID];
            
            // Start the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
            
            [self.serviceDrive executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                                      GTLDriveFile *updatedFile,
                                                                      NSError *error) {
                // End the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                
                if (error == nil)
                {
                    self.moveFileIndex++;
                    
                    // Send progress
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMMoveProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithFloat:(float)self.moveFileIndex/(float)self.moveFilesArray.count],@"progress",
                                                       [NSString stringWithFormat:@"%lu/%lu done",self.moveFileIndex,(unsigned long)self.moveFilesArray.count],@"info",
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
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       [error localizedDescription],@"error",
                                                       nil]];
                    });
                }
            }];
        }
        else
        {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:NO],@"success",
                                         [error localizedDescription],@"error",
                                         nil]];
            });
        }
    }];
}

- (void)cancelMoveTask
{
    [self.moveTicket cancelTicket];
    self.moveFilesArray = nil;
    self.moveDestFolder = nil;
    
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
}
#endif

#pragma mark - copy management

#ifndef APP_EXTENSION
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    self.cpyFilesArray = files;
    self.cpyFileIndex = 0;
    self.cpyDestFolder = destFolder;
    self.cpyOverwrite = overwrite;
    
    // Send initial progress
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMCopyProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSNumber numberWithFloat:0.0f],@"progress",
                                       nil]];
    });

    [self copyNextFile];
}

- (void)copyNextFile
{
    //FIXME : handle overwrite option
    // Point to file to copy
    FileItem *file = [self.cpyFilesArray objectAtIndex:self.cpyFileIndex];
    
    // File object used for the copy.
    GTLDriveFile *fileObj = [GTLDriveFile object];
    fileObj.title = file.name;
    GTLDriveParentReference *reference = [[GTLDriveParentReference alloc] init];
    if ([[self.cpyDestFolder.objectIds lastObject] isEqualToString:kRootID])
    {
        reference.identifier = @"root";
        reference.isRoot = [NSNumber numberWithBool:TRUE];
    }
    else
    {
        reference.identifier = [self.cpyDestFolder.objectIds lastObject];
        reference.isRoot = [NSNumber numberWithBool:FALSE];
    }
    fileObj.parents = [NSArray arrayWithObject:reference];
    
    GTLQueryDrive *copyQuery =[GTLQueryDrive queryForFilesCopyWithObject:fileObj fileId:[file.objectIds lastObject]];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.cpyTicket =
    [self.serviceDrive executeQuery:copyQuery completionHandler:^(GTLServiceTicket *ticket,
                                                                  id object,
                                                                  NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (error == nil)
        {
            self.cpyFileIndex++;
            
            // Send progress
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithFloat:(float)self.cpyFileIndex/(float)self.cpyFilesArray.count],@"progress",
                                               [NSString stringWithFormat:@"%lu/%lu done",self.cpyFileIndex,(unsigned long)self.cpyFilesArray.count],@"info",
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
                    [self copyNextFile];
                });
            }
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               error.localizedDescription,@"error",
                                               nil]];
            });
        }
    }];
}

- (void)cancelCopyTask
{
    [self.cpyTicket cancelTicket];
    self.cpyFilesArray = nil;
    self.cpyDestFolder = nil;
    
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
}
#endif

#pragma mark - Download management

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
    __weak typeof(self) weakSelf = self;

    self.fetcher = [self.serviceDrive.fetcherService fetcherWithURLString:file.downloadUrl];
    self.fetcher.downloadPath = localName;
    [self.fetcher setReceivedDataBlock:^(NSData *data) {
        float progress = weakSelf.fetcher.downloadedLength / [file.fileSizeNumber floatValue];
        // Do something with progress
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.delegate CMDownloadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithFloat:progress],@"progress",
                                                   [NSNumber numberWithLongLong:weakSelf.fetcher.downloadedLength],@"downloadedBytes",
                                                   file.fileSizeNumber,@"totalBytes",
                                                   nil]];
        });

    }];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (error == nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES],@"success",
                                                   nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   error.localizedDescription,@"error",
                                                   nil]];
            });

        }
    }];
}

- (void)cancelDownloadTask
{
    // Cancel request
    [self.fetcher stopFetching];
    self.fetcher = nil;
    
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
}

#pragma mark - Upload management

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
    __weak typeof(self) weakSelf = self;

    // Generate mime string
    CFStringRef fileExtension = (__bridge CFStringRef)file.type;
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    NSString *mimeTypeString = (__bridge_transfer NSString *)MIMEType;
    
    // Prepare upload
    GTLDriveFile *destFile = [GTLDriveFile object];
    destFile.title = file.name;
    destFile.mimeType = mimeTypeString;
    
    NSString *ressourceID = [destFolder.objectIds lastObject];
    if (ressourceID.length && ![ressourceID isEqualToString:kRootID])
    {
        GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
        parentRef.identifier = ressourceID;
        destFile.parents = [NSArray arrayWithObject:parentRef];
    }

    FileItem *fileToReplace = nil;
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
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:file.fullPath];
    
    GTLUploadParameters *uploadParameters = [GTLUploadParameters uploadParametersWithFileHandle:fileHandle
                                                                                       MIMEType:mimeTypeString];
    GTLQueryDrive *query = nil;

    if (fileToReplace)
    {
        if (overwrite)
        {
            query = [GTLQueryDrive queryForFilesUpdateWithObject:destFile
                                                          fileId:[[fileToReplace objectIds] lastObject]
                                                uploadParameters:uploadParameters];
        }
    }
    else
    {
        query = [GTLQueryDrive queryForFilesInsertWithObject:destFile
                                            uploadParameters:uploadParameters];
    }
    
    if (query)
    {
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        self.uploadTicket = [self.serviceDrive executeQuery:query
                                          completionHandler:^(GTLServiceTicket *ticket,
                                                              GTLDriveFile *insertedFile, NSError *error) {
              // End the network activity spinner
              [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                                              
              [fileHandle closeFile];
              if (error == nil)
              {
                  dispatch_async(dispatch_get_main_queue(), ^{
                      [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:YES],@"success",
                                                       nil]];
                  });
              }
              else
              {
                  dispatch_async(dispatch_get_main_queue(), ^{
                      [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       [error description],@"error",
                                                       nil]];
                  });
              }
          }];
        
        self.uploadTicket.uploadProgressBlock = ^(GTLServiceTicket *ticket,
                                                  unsigned long long numberOfBytesUploaded,
                                                  unsigned long long dataLength) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate CMUploadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithLongLong:numberOfBytesUploaded],@"uploadedBytes",
                                                     file.fileSizeNumber,@"totalBytes",
                                                     [NSNumber numberWithFloat:(float)((float)numberOfBytesUploaded/(float)([file.fileSizeNumber longLongValue]))],@"progress",
                                                     nil]];
            });
        };
    }
    else
    {
        [fileHandle closeFile];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             NSLocalizedString(@"File exists", nil),@"error",
                                             nil]];
        });
    }
}

- (void)cancelUploadTask
{
    // Cancel request
    [self.uploadTicket cancelTicket];
    self.uploadTicket = nil;
    
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

}

#pragma mark - search management

#ifndef APP_EXTENSION
- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder
{
    NSString *search = [NSString stringWithFormat:@"title contains '%@'",searchString];
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
    query.q = search;
    
    self.searchTicket =
        [self.serviceDrive executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                                  GTLDriveFileList *files,
                                                                  NSError *error) {
        if (error == nil)
        {
            // Iterate over files.items array
            NSMutableArray *filesOutputArray = [NSMutableArray arrayWithCapacity:[files.items count]];
            for (GTLDriveFile *file in files.items)
            {
                NSDictionary *dictItem;
                // To present folder results, we would have to query for full path, so we only show file results
                if (![file.mimeType isEqualToString:@"application/vnd.google-apps.folder"])
                {
                    dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSNumber numberWithBool:NO],@"isdir",
                                file.title,@"filename",
                                file.identifier,@"id",
                                file.fileSize,@"filesizenumber",
                                [NSNumber numberWithBool:YES],@"writeaccess",
                                [NSNumber numberWithDouble:[file.modifiedDate.date timeIntervalSince1970]],@"date",
                                file.fileExtension,@"type",
                                file.downloadUrl,@"url",
                                nil];
                }
                [filesOutputArray addObject:dictItem];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:YES],@"success",
                                                 filesOutputArray,@"filesList",
                                                 nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [error description],@"error",
                                                 nil]];
            });
        }
    }];
}

- (void)cancelSearchTask
{
    [self.searchTicket cancelTicket];
}
#endif

#pragma mark - sharing management

#ifndef APP_EXTENSION
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password
{
    self.shareFilesArray = files;
    self.shareFileIndex = 0;
    self.sharedLinks = [[NSMutableString alloc] init];
    
    // Send initial progress
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
    
    GTLDrivePermission *newPermission = [GTLDrivePermission object];
    newPermission.value = nil;
    newPermission.type = @"anyone";
    newPermission.role = @"reader";
    newPermission.withLink = [NSNumber numberWithBool:YES];
    
    GTLQueryDrive *query = [GTLQueryDrive queryForPermissionsInsertWithObject:newPermission fileId:[file.objectIds lastObject]];
    
    [self.serviceDrive executeQuery:query
          completionHandler:^(GTLServiceTicket* ticket, GTLDrivePermission* permission, NSError* error) {
          if (error == nil)
          {
              if (file.isDir)
              {
                 [self.sharedLinks appendFormat:@"%@ : https://drive.google.com/folderview?id=%@\r\n",file.name,[file.objectIds lastObject]];
              }
              else
              {
                  [self.sharedLinks appendFormat:@"%@ : https://drive.google.com/open?id=%@\r\n",file.name,[file.objectIds lastObject]];
              }
              
              self.shareFileIndex++;
              
              // Send progress
              dispatch_async(dispatch_get_main_queue(), ^{
                  [self.delegate CMShareProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithFloat:(float)self.shareFileIndex/(float)self.shareFilesArray.count],@"progress",
                                                 [NSString stringWithFormat:@"%lu/%lu done",self.shareFileIndex,(unsigned long)self.shareFilesArray.count],@"info",
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
          else
          {
              dispatch_async(dispatch_get_main_queue(), ^{
                  [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:NO],@"success",
                                                  error.localizedDescription,@"error",
                                                  nil]];
              });
          }
    }];
}
#endif

#pragma mark - url management

#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file
{
    NSString *url = [file.downloadUrl stringByAppendingString:[NSString stringWithFormat:@"&access_token=%@",
                                                               ((GTMOAuth2Authentication *)self.serviceDrive.authorizer).accessToken]];
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.url = [NSURL URLWithString:url];
    networkConnection.urlType = URLTYPE_HTTP;
    
    return networkConnection;
}
#endif

#pragma mark - supported features

- (NSInteger)supportedFeaturesAtPath:(NSString *)path
{
    return (CMSupportedFeaturesMaskFileDelete      |
            CMSupportedFeaturesMaskFolderDelete    |
            CMSupportedFeaturesMaskDeleteCancel    |
            CMSupportedFeaturesMaskFolderCreate    |
            CMSupportedFeaturesMaskFileRename      |
            CMSupportedFeaturesMaskFolderRename    |
            CMSupportedFeaturesMaskFileMove        |
            CMSupportedFeaturesMaskFolderMove      |
            CMSupportedFeaturesMaskMoveCancel      |
            CMSupportedFeaturesMaskFileCopy        |
            CMSupportedFeaturesMaskCopyCancel      |
            CMSupportedFeaturesMaskFileDownload    |
            CMSupportedFeaturesMaskDownloadCancel  |
            CMSupportedFeaturesMaskFileUpload      |
            CMSupportedFeaturesMaskUploadCancel    |
            CMSupportedFeaturesMaskSearch          |
            CMSupportedFeaturesMaskSearchCancel    |
            CMSupportedFeaturesMaskFileShare       |
            CMSupportedFeaturesMaskFolderShare     |
            CMSupportedFeaturesMaskQTPlayer        |
            CMSupportedFeaturesMaskVideoSeek       |
            CMSupportedFeaturesMaskAirPlay         |
            CMSupportedFeaturesMaskGoogleCast
            );
}

#ifndef APP_EXTENSION
- (NSInteger)supportedSharingFeatures
{
    return CMSupportedSharingNone;
}
#endif

@end
