//
//  CMUPnP.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "CMUPnP.h"
#import "ISO8601DateFormatter.h"

@implementation CMUPnP

- (id)init
{
    self = [super init];
    if (self)
    {
        _manager = [AFHTTPRequestOperationManager manager];
        _mutableObjectList = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark - Server Info

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           [NSString stringWithFormat:NSLocalizedString(@"Server Name : %@",nil),_UPNPdevice.friendlyName],
                           [NSString stringWithFormat:NSLocalizedString(@"Type : %@",nil), _UPNPdevice.type],
                           [NSString stringWithFormat:NSLocalizedString(@"%@",nil), _UPNPdevice.uuid],
                           nil];
    return serverInfo;
}

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
    if (!_UPNPdevice)
    {
        _UPNPdevice = (MediaServer1Device *)self.userAccount.serverObject;
    }

    _UPNProotID = (NSString *)[folder.objectIds lastObject];
    
    NSMutableString *outResult = [[NSMutableString alloc] init];
    NSMutableString *outNumberReturned = [[NSMutableString alloc] init];
    NSMutableString *outTotalMatches = [[NSMutableString alloc] init];
    NSMutableString *outUpdateID = [[NSMutableString alloc] init];
    
    [[_UPNPdevice contentDirectory] BrowseWithObjectID:_UPNProotID BrowseFlag:@"BrowseDirectChildren" Filter:@"*" StartingIndex:@"0" RequestedCount:@"0" SortCriteria:@"+dc:title" OutResult:outResult OutNumberReturned:outNumberReturned OutTotalMatches:outTotalMatches OutUpdateID:outUpdateID];
    
    [_mutableObjectList removeAllObjects];
    NSData *didl = [outResult dataUsingEncoding:NSUTF8StringEncoding];
    MediaServerBasicObjectParser *parser = [[MediaServerBasicObjectParser alloc] initWithMediaObjectArray:_mutableObjectList itemsOnly:NO];
    [parser parseFromData:didl];

    NSMutableArray *filesOutputArray = [NSMutableArray arrayWithCapacity:[_mutableObjectList count]];
    // To convert ISO8601 date to NSDate
    ISO8601DateFormatter *dateFormatter = [[ISO8601DateFormatter alloc] init];

    for (MediaServer1BasicObject *item in _mutableObjectList)
    {
        {
            if ([item isContainer])
            {
                MediaServer1ContainerObject *containerItem = (MediaServer1ContainerObject *)item;
                NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                          @"1",@"isdir",
                                          [containerItem title],@"filename",
                                          [containerItem objectID],@"id",
                                          @"dir",@"type",
                                          nil];
                [filesOutputArray addObject:dictItem];
            }
            else
            {
                MediaServer1ItemObject *mediaItem = (MediaServer1ItemObject *)item;
                
                NSString *fileType = [mediaItem.uri pathExtension];
                NSString *name = nil;
                
                // filter out parameters in extension
                NSRange position = [fileType rangeOfString:@"?"];
                if (position.location != NSNotFound)
                {
                    fileType = [fileType substringToIndex:position.location];
                }
                if (fileType.length > 0)
                {
                    name = [NSString stringWithFormat:@"%@.%@",[mediaItem title],fileType];
                }
                else
                {
                    name = [mediaItem title];
                }
                
                if ([mediaItem.uri hasPrefix:@"rtsp://"])
                {
                    fileType = @"rtsp";
                }
                else if (fileType.length == 0)
                {
                    fileType = @"avi";
                }
                
                // Build entry
                NSMutableDictionary *dictItem= [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                @"0",@"isdir",
                                                name,@"filename",
                                                [mediaItem uriCollection],@"id",
                                                fileType,@"type",
                                                nil];
                if ([mediaItem.size longLongValue] != 0)
                {
                    [dictItem addEntriesFromDictionary:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:[mediaItem.size longLongValue]]
                                                                                   forKey:@"filesizenumber"]];
                }
                
                if (mediaItem.date)
                {
                    NSDate *date = [dateFormatter dateFromString:mediaItem.date];

                    [dictItem addEntriesFromDictionary:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:[date timeIntervalSince1970]]
                                                                                   forKey:@"date"]];
                }
                
                [filesOutputArray addObject:dictItem];
            }
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

#pragma mark - Download management

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
    __weak typeof(self) weakSelf = self;
    
    void (^successBlock)(AFHTTPRequestOperation *,id) = ^(AFHTTPRequestOperation *operation, id responseObject) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
        });
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *, NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([error code] != kCFURLErrorCancelled)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [error description],@"error",
                                                   nil]];
                
            });
        }
        // Delete partially downloaded file
        [[NSFileManager defaultManager] removeItemAtPath:localName error:NULL];
    };
    
    NSURL *url = [self urlForFile:file].url;
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    _downloadOperation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    // Set destination file
    _downloadOperation.outputStream = [NSOutputStream outputStreamToFileAtPath:localName append:NO];
    
    __block long long lastNotifiedProgress = 0;
    [_downloadOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        // send a notification every 0,5% of progress (to limit the impact on performances)
        if ((totalBytesRead >= lastNotifiedProgress + totalBytesExpectedToRead/200) || (totalBytesRead == totalBytesExpectedToRead))
        {
            lastNotifiedProgress = totalBytesRead;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate CMDownloadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithLongLong:totalBytesRead],@"downloadedBytes",
                                                       [NSNumber numberWithLongLong:totalBytesExpectedToRead],@"totalBytes",
                                                       [NSNumber numberWithFloat:(float)((float)totalBytesRead/(float)totalBytesExpectedToRead)],@"progress",
                                                       nil]];
            });
        }
    }];
    
    [_downloadOperation setCompletionBlockWithSuccess:successBlock
                                              failure:failureBlock];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [_downloadOperation start];
}

- (void)cancelDownloadTask
{
    // Cancel request
    [_downloadOperation cancel];
    
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
}

#pragma mark - url management

- (NetworkConnection *)urlForFile:(FileItem *)file
{
    NetworkConnection *networkConnection = nil;
    
    NSArray *uriCollectionKeys = [[file.objectIds lastObject] allKeys];
    NSUInteger count = uriCollectionKeys.count;
    NSRange position;
    NSInteger correctIndex = -1;
    // Look for video
    for (NSInteger i = 0; i < count; i++)
    {
        position = [uriCollectionKeys[i] rangeOfString:@"http-get:*:video/"];
        if (position.location != NSNotFound)
            correctIndex = i;
    }
    // If not found, look for audio
    if (correctIndex < 0)
    {
        for (NSInteger i = 0; i < count; i++)
        {
            position = [uriCollectionKeys[i] rangeOfString:@"http-get:*:audio/"];
            if (position.location != NSNotFound)
            {
                correctIndex = i;
                break;
            }
        }
    }
    // If not found, look for image (large)
    if (correctIndex < 0)
    {
        for (NSInteger i = 0; i < count; i++)
        {
            position = [uriCollectionKeys[i] rangeOfString:@"http-get:*:image/"];
            if (position.location != NSNotFound)
            {
                position = [uriCollectionKeys[i] rangeOfString:@"DLNA.ORG_PN=JPEG_LRG"];
                if (position.location != NSNotFound)
                {
                    correctIndex = i;
                }
            }
        }
    }
    // If not found, look for image (any)
    if (correctIndex < 0)
    {
        for (NSInteger i = 0; i < count; i++)
        {
            position = [uriCollectionKeys[i] rangeOfString:@"http-get:*:image/"];
            if (position.location != NSNotFound)
                correctIndex = i;
        }
    }
    
    if (correctIndex >= 0)
    {
        NSArray *uriCollectionObjects = [[file.objectIds lastObject] allValues];
        
        networkConnection = [[NetworkConnection alloc] init];
        networkConnection.url = [NSURL URLWithString:uriCollectionObjects[correctIndex]];
        networkConnection.urlType = URLTYPE_HTTP;
    }
    
    NSLog(@"networkConnection.url %@",networkConnection.url);
  	return networkConnection;
}

#pragma mark - supported features

- (long long)supportedFeaturesAtPath:(NSString *)path
{
    long long features = CMSupportedFeaturesMaskVLCPlayer      |
                         CMSupportedFeaturesMaskQTPlayer       |
                         CMSupportedFeaturesMaskGoogleCast     |
                         CMSupportedFeaturesMaskFileDownload   |
                         CMSupportedFeaturesMaskDownloadCancel |
                         CMSupportedFeaturesMaskCacheImage;
    return features;
}

@end
