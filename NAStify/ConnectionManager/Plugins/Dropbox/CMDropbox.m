//
//  CMDropbox.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "CMDropbox.h"
#import "SBNetworkActivityIndicator.h"
#import "NSStringAdditions.h"

// This size is hardcoded in DBRestClient.m from Dropbox SDK :-|
#define CHUNK_SIZE 2*1024*1024

@implementation CMDropbox

#pragma mark - Server Info

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           NSLocalizedString(@"Server Model : Dropbox",nil),
                           [NSString stringWithFormat:NSLocalizedString(@"UserID : %@",nil), self.userAccount.userName],
                           [NSString stringWithFormat:NSLocalizedString(@"Dropbox SDK : %@",nil),kDBSDKVersion],
                           nil];
    return serverInfo;
}

#pragma mark - login/logout management

- (BOOL)login
{
    [DBRequest setNetworkRequestDelegate:self];
    
    if ([[DBSession sharedSession] isLinked])
    {
        self.restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession] userId:self.userAccount.userName];
        self.restClient.delegate = self;
        self.uploadRestClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]  userId:self.userAccount.userName];
        self.uploadRestClient.delegate = self;

        return NO;
    }
    else
    {
        // This should not be possible
    }
    
    return YES;
}

- (BOOL)logout
{
    [self.restClient cancelAllRequests];
    return NO;
}

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
    [self.restClient loadMetadata:folder.path withHash:nil];
}

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata
{
    if (client == self.uploadRestClient)
    {
        if (self.uploadOverwrite)
        {
            self.existingFileRevision = metadata.rev;
        }

        [self.uploadRestClient uploadFileChunk:nil
                                        offset:0
                                      fromPath:self.uploadedFile.fullPath];
    }
    else
    {
        NSString *path = metadata.path;
        NSMutableArray *filesOutputArray = [NSMutableArray arrayWithCapacity:[metadata.contents count]];
        for (DBMetadata *child in metadata.contents)
        {
            /* File type */
            NSString *fileType = [[child.path pathExtension] lowercaseString];
            
            /* Date */
            NSDate *mdate = child.lastModifiedDate;
            NSNumber *fileDateNumber = [NSNumber numberWithDouble:[mdate timeIntervalSince1970]];
            
            NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithBool:child.isDirectory],@"isdir",
                                      child.filename,@"filename",
                                      [NSNumber numberWithLongLong:child.totalBytes],@"filesizenumber",
                                      [NSNumber numberWithBool:NO],@"iscompressed",
                                      [NSNumber numberWithBool:YES],@"writeaccess",
                                      fileDateNumber,@"date",
                                      fileType,@"type",
                                      nil];
            
            [filesOutputArray addObject:dictItem];
        }
        [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    path,@"path",
                                    filesOutputArray,@"filesList",
                                    nil]];
    }
}

- (void)restClient:(DBRestClient*)client metadataUnchangedAtPath:(NSString*)path
{
    NSLog(@"metadataUnchangedAtPath");
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error
{
    if (client == self.uploadRestClient)
    {
        if (error.code == 404)
        {
            // File not existing on the server, upload new file
            [self.uploadRestClient uploadFileChunk:nil
                                            offset:0
                                          fromPath:self.uploadedFile.fullPath];
        }
        else
        {
            self.uploadedFile = nil;
            self.uploadedDestFolder = nil;
            self.uploadOverwrite = NO;
            self.existingFileRevision = nil;
            
            [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             [error description],@"error",
                                             nil]];
        }
    }
    else
    {
        [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO],@"success",
                                    [error description],@"error",
                                    nil]];
    }
}

#pragma mark - space info management

- (void)spaceInfoAtPath:(FileItem *)folder
{
    [self.restClient loadAccountInfo];
}

- (void)restClient:(DBRestClient*)client loadedAccountInfo:(DBAccountInfo*)info
{
    long long totalSpace = info.quota.totalBytes;
    long long usedSpace = info.quota.totalConsumedBytes;
    long long freeSpace = totalSpace - usedSpace;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMSpaceInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    [NSNumber numberWithLongLong:totalSpace],@"totalspace",
                                    [NSNumber numberWithLongLong:freeSpace],@"freespace",
                                    nil]];
    });
}

- (void)restClient:(DBRestClient*)client loadAccountInfoFailedWithError:(NSError*)error
{
    // Do nothing
}

#pragma mark - Folder creation management

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
{
    NSString *fullPath = [folder.path stringByAppendingPathComponent:folderName];
    [self.restClient createFolder:fullPath];
}

- (void)restClient:(DBRestClient*)client createdFolder:(DBMetadata*)folder
{
    [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithBool:YES],@"success",
                                    nil]];
}

- (void)restClient:(DBRestClient*)client createFolderFailedWithError:(NSError*)error
{
    [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithBool:NO],@"success",
                                   [error description],@"error",
                                   nil]];
}

#pragma mark - delete management

- (void)deleteFiles:(NSArray *)files
{
    deleteRequestsCount = 0;
    for (FileItem *file in files)
    {
        deleteRequestsCount ++;
        [self.restClient deletePath:file.path];
    }
}

- (void)restClient:(DBRestClient*)client deletedPath:(NSString *)path
{
    deleteRequestsCount--;
    if (deleteRequestsCount == 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:YES],@"success",
                                             nil]];
        });
    }
}

- (void)restClient:(DBRestClient*)client deletePathFailedWithError:(NSError*)error
{
    deleteRequestsCount--;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:NO],@"success",
                                         [error description],@"error",
                                         nil]];
    });
}

#pragma mark - copy management

- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    copyRequestsCount = 0;
    for (FileItem *file in files)
    {
        copyRequestsCount ++;
        NSString *destPath = [destFolder.path stringByAppendingPathComponent:file.name];
        [self.restClient copyFrom:file.path toPath:destPath];
    }
}

- (void)restClient:(DBRestClient*)client copiedPath:(NSString *)fromPath to:(DBMetadata *)to
{
    copyRequestsCount --;
    if (copyRequestsCount == 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:YES],@"success",
                                             nil]];
        });
    }
}

- (void)restClient:(DBRestClient*)client copyPathFailedWithError:(NSError*)error
{
    // [error userInfo] contains the root and path
    copyRequestsCount --;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:NO],@"success",
                                         [error description],@"error",
                                         nil]];
    });
}

#pragma mark - Move/Rename management

- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    moveActionIsRename = NO;
    moveRequestsCount = 0;
    for (FileItem *file in files)
    {
        moveRequestsCount ++;
        NSString *destFile = [destFolder.path stringByAppendingPathComponent:file.name];
        [self.restClient moveFrom:file.path
                           toPath:destFile];
    }
}

- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    moveActionIsRename = YES;
    
    NSString *oldPath = [folder.path stringByAppendingPathComponent:oldFile.name];
    NSString *newPath = [folder.path stringByAppendingPathComponent:newName];
    [self.restClient moveFrom:oldPath
                       toPath:newPath];
    
}

- (void)restClient:(DBRestClient*)client movedPath:(NSString *)from_path to:(DBMetadata *)result
{
    if (moveActionIsRename)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:YES],@"success",
                                     nil]];
        });
        moveActionIsRename = NO;
    }
    else
    {
        moveRequestsCount --;
        if (moveRequestsCount == 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
    }
}

- (void)restClient:(DBRestClient*)client movePathFailedWithError:(NSError*)error
{
    // [error userInfo] contains the root and path
    if (moveActionIsRename)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],@"success",
                                     [error description],@"error",
                                     nil]];
        });
    }
    else
    {
        moveRequestsCount --;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [error description],@"error",
                                           nil]];
        });
    }
}

#pragma mark - Download management

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
    self.downloadedFile = file.path;
    self.downloadedFileSize = [file.fileSizeNumber longLongValue];
    [self.restClient loadFile:file.path intoPath:localName];
}

- (void)cancelDownloadTask
{
    // Cancel request
    [self.restClient cancelFileLoad:self.downloadedFile];
}

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)localPath {
    self.downloadedFile = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:YES],@"success",
                                           nil]];
    });
}

- (void)restClient:(DBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath
{

    dispatch_async(dispatch_get_main_queue(), ^{
        long long downloaded = (long long)(progress * (float)self.downloadedFileSize);
        [self.delegate CMDownloadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithFloat:progress],@"progress",
                                           [NSNumber numberWithLongLong:downloaded],@"downloadedBytes",
                                           [NSNumber numberWithLongLong:self.downloadedFileSize],@"totalBytes",
                                           nil]];
    });
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error {
    self.downloadedFile = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [error description],@"error",
                                           nil]];
    });
}

#pragma mark - Upload management

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
    self.uploadedFile = file;
    self.uploadedDestFolder = destFolder.path;
    self.uploadOverwrite = overwrite;
    self.existingFileRevision = nil;

    // Check if file exists on server, upload will be started in loadmetadata callback
    [self.uploadRestClient loadMetadata:[destFolder.path stringByAppendingPathComponent:self.uploadedFile.name]];
}

- (void)cancelUploadTask
{
    // Cancel request
    [self.uploadRestClient cancelAllRequests];
    self.uploadedFile = nil;
}

- (void)restClient:(DBRestClient *)client uploadedFileChunk:(NSString *)uploadId newOffset:(unsigned long long)offset
          fromFile:(NSString *)localPath expires:(NSDate *)expiresDate
{
    if (offset >= [self.uploadedFile.fileSizeNumber longLongValue])
    {
        //Commit file
        [self.uploadRestClient uploadFile:self.uploadedFile.name
                                   toPath:self.uploadedDestFolder
                            withParentRev:self.existingFileRevision
                             fromUploadId:uploadId];
    }
    else
    {
        //Send the next chunk and update the progress HUD.
        [self.uploadRestClient uploadFileChunk:uploadId offset:offset fromPath:localPath];
    }
}

- (void)restClient:(DBRestClient *)client uploadFileChunkFailedWithError:(NSError *)error
{
    self.uploadedFile = nil;

    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],@"success",
                                     [error description],@"error",
                                     nil]];
}

- (void)restClient:(DBRestClient *)client uploadFileChunkProgress:(CGFloat)progress
           forFile:(NSString *)uploadId offset:(unsigned long long)offset fromPath:(NSString *)localPath
{
    long long chunkSize = CHUNK_SIZE;
    if ([self.uploadedFile.fileSizeNumber longLongValue] - offset < CHUNK_SIZE)
    {
        chunkSize = [self.uploadedFile.fileSizeNumber longLongValue] - offset;
    }
    float uploadedBytes = progress * chunkSize + offset;
    float uploadProgress = (float) (uploadedBytes / [self.uploadedFile.fileSizeNumber floatValue]);
    [self.delegate CMUploadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithFloat:uploadedBytes],@"uploadedBytes",
                                     self.uploadedFile.fileSizeNumber,@"totalBytes",
                                     [NSNumber numberWithFloat:uploadProgress],@"progress",
                                     nil]];
}

- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath fromUploadId:(NSString *)uploadId
          metadata:(DBMetadata *)metadata
{
    self.uploadedFile = nil;
    self.uploadedDestFolder = nil;
    self.uploadOverwrite = NO;
    self.existingFileRevision = nil;

    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:YES],@"success",
                                     nil]];
}
- (void)restClient:(DBRestClient *)client uploadFromUploadIdFailedWithError:(NSError *)error
{
    self.uploadedFile = nil;
    self.uploadedDestFolder = nil;
    self.uploadOverwrite = NO;
    self.existingFileRevision = nil;
    
    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],@"success",
                                     [error description],@"error",
                                     nil]];
}

#pragma mark - search management

- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder
{
    [self.restClient searchPath:folder.path forKeyword:searchString];
}

- (void)restClient:(DBRestClient*)restClient loadedSearchResults:(NSArray*)results
           forPath:(NSString*)path keyword:(NSString*)keyword
{
    NSMutableArray *filesOutputArray = [NSMutableArray arrayWithCapacity:[results count]];
    for (DBMetadata *child in results)
    {
        /* File type */
        NSString *fileType = [[child.path pathExtension] lowercaseString];
        
        /* Date */
        NSDate *mdate = child.lastModifiedDate;
        NSNumber *fileDateNumber = [NSNumber numberWithDouble:[mdate timeIntervalSince1970]];
        
        NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithBool:child.isDirectory],@"isdir",
                                  child.filename,@"filename",
                                  child.path,@"path",
                                  [NSNumber numberWithLongLong:child.totalBytes],@"filesizenumber",
                                  [NSNumber numberWithBool:NO],@"iscompressed",
                                  [NSNumber numberWithBool:YES],@"writeaccess",
                                  fileDateNumber,@"date",
                                  fileType,@"type",
                                  nil];
        
        [filesOutputArray addObject:dictItem];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:YES],@"success",
                                         filesOutputArray,@"filesList",
                                         nil]];
    });
}

- (void)restClient:(DBRestClient*)restClient searchFailedWithError:(NSError*)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:NO],@"success",
                                         [error description],@"error",
                                         nil]];
    });
}

#pragma mark - sharing management

- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password
{
    self.sharedFiles = [NSMutableArray arrayWithArray:files];
    self.sharedLinks = [NSMutableString string];
    
    FileItem *file = [self.sharedFiles objectAtIndex:0];
    [self.restClient loadSharableLinkForFile:file.path];
}

- (void)restClient:(DBRestClient*)restClient loadedSharableLink:(NSString*)link
           forFile:(NSString*)path
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.sharedLinks appendFormat:@"%@ : %@\r\n",[path lastPathComponent], link];
        [self.sharedFiles removeObjectAtIndex:0];
        if ([self.sharedFiles count] == 0)
        {
            // Send links to delegate
            [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:YES],@"success",
                                            self.sharedLinks,@"shares",
                                            nil]];
        }
        else
        {
            // Process next file to share
            FileItem *file = [self.sharedFiles objectAtIndex:0];
            [self.restClient loadSharableLinkForFile:file.path];
        }
    });
}

- (void)restClient:(DBRestClient*)restClient loadSharableLinkFailedWithError:(NSError*)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        [error description],@"error",
                                        nil]];
        self.sharedLinks = nil;
        [self.sharedFiles removeAllObjects];
    });
}

#pragma mark - url management

- (NetworkConnection *)urlForFile:(FileItem *)file
{
    streamableURL = nil;
    [self.restClient loadStreamableURLForFile:file.path];
    while (streamableURL == nil)
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    }
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.url = streamableURL;
    networkConnection.urlType = URLTYPE_HTTP;
    
  	return networkConnection;
}

- (void)restClient:(DBRestClient*)restClient loadedStreamableURL:(NSURL*)url forFile:(NSString*)path
{
    NSLog(@"url %@ path %@",url,path);
    streamableURL = url;
}

- (void)restClient:(DBRestClient*)restClient loadStreamableURLFailedWithError:(NSError*)error
{
    //FIXME: this will block app in urlForFile method
    NSLog(@"loadStreamableURLFailedWithError");
}

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

- (NSInteger)supportedSharingFeatures
{
    return CMSupportedSharingNone;
}

#pragma mark - DBNetworkRequestDelegate methods

- (void)networkRequestStarted
{
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
}

- (void)networkRequestStopped
{
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
}

@end
