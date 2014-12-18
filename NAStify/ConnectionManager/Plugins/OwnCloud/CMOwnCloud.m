//
//  CMUPnP.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "CMOwnCloud.h"
#import "SSKeychain.h"
#import "OCFrameworkConstants.h"
#import "OCFileDto.h"
#import "OCErrorMsg.h"

typedef struct {
    long long file_size; /* size of the handled file in bytes */
} file_ctx;

static file_ctx DownloadProgressObserverContext;
static file_ctx UploadProgressObserverContext;

@implementation CMOwnCloud

- (id)init
{
    self = [super init];
    if (self)
    {
        self.ocCommunication = [[OCCommunication alloc] init];
    }
    return self;
}

- (NSString *)createUrlWithCredentials:(BOOL)credentials
{
    NSString * url = self.userAccount.server;
    
    if (self.userAccount.boolSSL)
    {
        url = @"https://";
    }
    else
    {
        url = @"http://";
    }

    if (credentials)
    {
        NSString *password = [SSKeychain passwordForService:self.userAccount.uuid
                                                    account:@"password"];
        
        url = [url stringByAppendingFormat:@"%@:%@@", self.userAccount.userName, password];
    }
    
    url = [url stringByAppendingString:self.userAccount.server];

    if (self.userAccount.port && ([self.userAccount.port length] != 0))
    {
        url = [url stringByAppendingFormat:@":%@",self.userAccount.port];
    }
    
    if ([self.userAccount.settings objectForKey:@"path"])
    {
        url = [url stringByAppendingString:[self.userAccount.settings objectForKey:@"path"]];
    }
    return url;
}

- (NSString *)createUrlWithPath:(NSString *)path
{
    return [NSString stringWithFormat:@"%@/remote.php/webdav%@", [self createUrlWithCredentials:NO], path];
}

- (NSString *)createUrlWithCredentialsAndPath:(NSString *)path
{
    return [NSString stringWithFormat:@"%@/remote.php/webdav%@", [self createUrlWithCredentials:YES], path];
}


- (NSString *)stringForStatusCode:(NSInteger)statusCode
{
    NSString *errorMessage = nil;
    switch (statusCode)
    {
        case kOCErrorServerPathNotFound :
        {
            errorMessage = NSLocalizedString(@"Path not found",nil);
            break;
        }
        case kOCErrorServerUnauthorized :
        {
            errorMessage = NSLocalizedString(@"Incorrect User/Password",nil);
            break;
        }
        case kOCErrorServerMethodNotPermitted:
        {
            errorMessage = NSLocalizedString(@"Server method not permitted",nil);
        }
        case kOCErrorServerForbidden :
        {
            errorMessage = NSLocalizedString(@"Forbidden",nil);
            break;
        }
        case kOCErrorServerTimeout :
        {
            errorMessage = NSLocalizedString(@"Request timeout",nil);
            break ;
        }
        case kOCErrorProxyAuth:
        {
            errorMessage = NSLocalizedString(@"Proxy access required",nil);
            break;
        }
    }
    return errorMessage;
}

- (NSString *)stringForErrorCode:(NSError *)error
{
    NSString *errorMessage = nil;
    switch (error.code)
    {
        case OCErrorForbidenCharacters :
        {
            errorMessage = NSLocalizedString(@"Forbiden characters",nil);
            break;
        }
        case OCErrorMovingDestinyNameHaveForbiddenCharacters:
        {
            errorMessage = NSLocalizedString(@"Forbiden characters",nil);
            break;
        }
        case OCErrorMovingTheDestinyAndOriginAreTheSame:
        {
            errorMessage = NSLocalizedString(@"Origin and destiny are the same",nil);
            break;
        }
        case OCErrorMovingFolderInsideHimself:
        {
            errorMessage = NSLocalizedString(@"Moving folder inside himself",nil);
            break;
        }
        case OCErrorFileToUploadDoesNotExist:
        {
            errorMessage = NSLocalizedString(@"Source file doesn't exist",nil);
            break;
        }
        default:
        {
            errorMessage = [error localizedDescription];
        }
    }
    return errorMessage;
}

#pragma mark - Server Info

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           NSLocalizedString(@"Server Type : ownCloud",nil),
                           nil];
    return serverInfo;
}

#pragma mark - login/logout management

- (BOOL)login
{
    if (self.userAccount.acceptUntrustedCertificate)
    {
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy defaultPolicy];
        securityPolicy.allowInvalidCertificates = YES;
        [self.ocCommunication setSecurityPolicy:securityPolicy];
    }
    
    NSString *password = [SSKeychain passwordForService:self.userAccount.uuid
                                                account:@"password"];

    [self.ocCommunication setCredentialsWithUser:self.userAccount.userName
                                     andPassword:password];
    
    // We list root folder to check if everything is ok
    
    void (^successBlock)(NSHTTPURLResponse *, NSArray *, NSString *) = ^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    nil]];
        });
    };
    
    void (^failureBlock)(NSHTTPURLResponse *, NSError *) = ^(NSHTTPURLResponse *response, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSString *errorMessage = [self stringForStatusCode:response.statusCode];
        if (errorMessage == nil)
        {
            switch (error.code)
            {
                case kCFURLErrorUserCancelledAuthentication:
                {
                    errorMessage = NSLocalizedString(@"Authentication problem (incorrect certificate ?)",nil);
                    break;
                }
                default:
                {
                    errorMessage = [error localizedDescription];
                    break;
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO],@"success",
                                    errorMessage,@"error",
                                    nil]];
        });
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.ocCommunication readFolder:[self createUrlWithPath:@"/"]
                     onCommunication:self.ocCommunication
                      successRequest:successBlock
                      failureRequest:failureBlock];
    
    return YES;
}

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
    NSLog(@"%@",[self createUrlWithPath:folder.path]);
    
    void (^successBlock)(NSHTTPURLResponse *, NSArray *, NSString *) = ^(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSMutableArray *filesOutputArray = nil;
        /* Build dictionary with items */
        filesOutputArray = [NSMutableArray arrayWithCapacity:[items count]];
        for (OCFileDto *ocFileDto in items)
        {
            NSLog( @"item path: %@%@" , ocFileDto.filePath, ocFileDto.fileName);
            if (ocFileDto.fileName)
            {
                NSString *name = (__bridge_transfer NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (CFStringRef)ocFileDto.fileName, CFSTR(""), kCFStringEncodingUTF8);
                
                NSString *type = @"";
                if (ocFileDto.isDirectory)
                {
                    // Remove tailing / from name
                    if ([name hasSuffix:@"/"])
                    {
                        name = [name substringToIndex:[name length]-1];
                    }
                }
                else if ([[name componentsSeparatedByString:@"."] count] > 1)
                {
                    type = [[ocFileDto.fileName componentsSeparatedByString:@"."] lastObject];
                }
                NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithBool:ocFileDto.isDirectory],@"isdir",
                                          name,@"filename",
                                          [NSString stringForSize:ocFileDto.size],@"filesize",
                                          [NSNumber numberWithLong:ocFileDto.size],@"filesizenumber",
                                          [NSNumber numberWithBool:YES],@"writeaccess",
                                          [NSNumber numberWithLong:ocFileDto.date],@"date",
                                          type,@"type",
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
    };

    void (^failureBlock)(NSHTTPURLResponse *, NSError *) = ^(NSHTTPURLResponse *response, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSString *errorMessage = [self stringForStatusCode:response.statusCode];
        if (errorMessage == nil)
        {
            errorMessage = [error localizedDescription];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        folder.path,@"path",
                                        errorMessage,@"error",
                                        nil]];
        });
    };
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

    [self.ocCommunication readFolder:[self createUrlWithPath:folder.path]
                     onCommunication:self.ocCommunication
                      successRequest:successBlock
                      failureRequest:failureBlock];
}

#pragma mark - Folder creation management

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder
{
    void (^successBlock)(NSHTTPURLResponse *, NSString *) = ^( NSHTTPURLResponse *response, NSString *redirectedServer) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:YES],@"success",
                                           nil]];
        });
    };
    
    void (^failureBlock)(NSHTTPURLResponse *, NSError *) = ^(NSHTTPURLResponse *response, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSString *errorMessage = [self stringForStatusCode:response.statusCode];
        if (errorMessage == nil)
        {
            errorMessage = [error localizedDescription];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           errorMessage,@"error",
                                           nil]];
        });
    };

    void (^errorBeforeBlock)(NSError *) = ^(NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [self stringForErrorCode:error],@"error",
                                           nil]];
        });
    };

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.ocCommunication createFolder:[self createUrlWithPath:[NSString stringWithFormat:@"%@/%@",folder.path,folderName]]
                       onCommunication:self.ocCommunication
                        successRequest:successBlock
                        failureRequest:failureBlock
                    errorBeforeRequest:errorBeforeBlock];
}

#pragma mark - delete management

#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files
{
    self.deleteFilesArray = files;
    self.deletingFileIndex = 0;
    self.deleteCancel = FALSE;
    
    // Send initial progress
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMDeleteProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithFloat:0.0f],@"progress",
                                         nil]];
    });

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self deleteNextFile];
}

- (void)deleteNextFile
{
    FileItem *file = [self.deleteFilesArray objectAtIndex:self.deletingFileIndex];
    
    void (^successBlock)(NSHTTPURLResponse *, NSString *) = ^( NSHTTPURLResponse *response, NSString *redirectedServer) {
        self.deletingFileIndex++;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDeleteProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithFloat:(float)self.deletingFileIndex/(float)self.deleteFilesArray.count],@"progress",
                                             [NSString stringWithFormat:@"%lu/%lu done",self.deletingFileIndex,(unsigned long)self.deleteFilesArray.count],@"info",
                                             nil]];
        });
        
        if (self.deletingFileIndex == self.deleteFilesArray.count)
        {
            // Last item deleted
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:YES],@"success",
                                                 nil]];
            });
        }
        else
        {
            if (self.deleteCancel == NO)
            {
                [self deleteNextFile];
            }
            else
            {
                // End the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            }
        }

    };
    
    void (^failureBlock)(NSHTTPURLResponse *, NSError *) = ^( NSHTTPURLResponse *response, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSString *errorMessage = [self stringForStatusCode:response.statusCode];
        if (errorMessage == nil)
        {
            errorMessage = [error localizedDescription];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             errorMessage,@"error",
                                             nil]];
        });
    };
    
    [self.ocCommunication deleteFileOrFolder:[self createUrlWithPath:file.path]
                             onCommunication:self.ocCommunication
                              successRequest:successBlock
                               failureRquest:failureBlock];
}

- (void)cancelDeleteTask
{
    self.deleteCancel = YES;
}
#endif

#pragma mark - Rename management

#ifndef APP_EXTENSION
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    void (^successBlock)(NSHTTPURLResponse *, NSString *) = ^( NSHTTPURLResponse *response, NSString *redirectedServer) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:YES],@"success",
                                     nil]];
        });
    };
    
    void (^failureBlock)(NSHTTPURLResponse *, NSError *) = ^( NSHTTPURLResponse *response, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSString *errorMessage = [self stringForStatusCode:response.statusCode];
        if (errorMessage == nil)
        {
            errorMessage = [error localizedDescription];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],@"success",
                                     errorMessage,@"error",
                                     nil]];
        });
    };
    
    void (^errorBeforeBlock)(NSError *) = ^(NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],@"success",
                                     [self stringForErrorCode:error],@"error",
                                     nil]];
        });
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.ocCommunication moveFileOrFolder:[self createUrlWithPath:oldFile.path]
                                 toDestiny:[self createUrlWithPath:[NSString stringWithFormat:@"%@/%@",folder.path,newName]]
                           onCommunication:self.ocCommunication
                            successRequest:successBlock
                            failureRequest:failureBlock
                        errorBeforeRequest:errorBeforeBlock];
}
#endif

#pragma mark - Move management

#ifndef APP_EXTENSION
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    self.moveFilesArray = files;
    self.movingFileIndex = 0;
    self.moveDestPath = destFolder.path;
    self.moveOverwrite = overwrite;
    self.moveCancel = NO;
    
    // Send initial progress
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMMoveProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSNumber numberWithFloat:0.0f],@"progress",
                                       nil]];
    });

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self moveNextFile];
}

- (void)moveNextFile
{
    FileItem *file = [self.moveFilesArray objectAtIndex:self.movingFileIndex];
    
    void (^successBlock)(NSHTTPURLResponse *, NSString *) = ^( NSHTTPURLResponse *response, NSString *redirectedServer) {
        self.movingFileIndex++;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMMoveProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithFloat:(float)self.movingFileIndex/(float)self.moveFilesArray.count],@"progress",
                                           [NSString stringWithFormat:@"%lu/%lu done",self.movingFileIndex,(unsigned long)self.moveFilesArray.count],@"info",
                                           nil]];
        });
        
        if (self.movingFileIndex == self.moveFilesArray.count)
        {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
        else
        {
            if (self.moveCancel == NO)
            {
                [self moveNextFile];
            }
            else
            {
                // End the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            }
        }
    };
    
    void (^failureBlock)(NSHTTPURLResponse *, NSError *) = ^( NSHTTPURLResponse *response, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSString *errorMessage = [self stringForStatusCode:response.statusCode];
        if (errorMessage == nil)
        {
            errorMessage = [error localizedDescription];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           errorMessage,@"error",
                                           nil]];
        });
    };
    
    void (^errorBeforeBlock)(NSError *) = ^(NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [self stringForErrorCode:error],@"error",
                                           nil]];
        });
    };
    
    [self.ocCommunication moveFileOrFolder:[self createUrlWithPath:file.path]
                                 toDestiny:[self createUrlWithPath:[NSString stringWithFormat:@"%@/%@",self.moveDestPath,file.name]]
                           onCommunication:self.ocCommunication
                            successRequest:successBlock
                            failureRequest:failureBlock
                        errorBeforeRequest:errorBeforeBlock];
}

- (void)cancelMoveTask
{
    self.moveCancel = YES;
}
#endif

#pragma mark - Sharing management

#ifndef APP_EXTENSION
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password
{
    self.sharedFilesArray = files;
    self.sharingFileIndex = 0;
    
    self.sharedLinks = [[NSMutableString alloc] init];
    
    // Send initial progress
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate CMShareProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithFloat:0.0f],@"progress",
                                        nil]];
    });
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self shareNextFile];
}

- (void)shareNextFile
{
    FileItem *file = [self.sharedFilesArray objectAtIndex:self.sharingFileIndex];
    
    void (^successBlock)(NSHTTPURLResponse *, NSString *, NSString *) = ^(NSHTTPURLResponse *response, NSString *sharedToken, NSString *redirectedServer) {
        [self.sharedLinks appendFormat:@"%@ : %@/public.php?service=files&t=%@\r\n",file.name, [self createUrlWithCredentials:NO],sharedToken];
        
        self.sharingFileIndex++;
        
        // Send progress
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithFloat:(float)self.sharingFileIndex/(float)self.sharedFilesArray.count],@"progress",
                                            [NSString stringWithFormat:@"%lu/%lu done",self.sharingFileIndex,(unsigned long)self.sharedFilesArray.count],@"info",
                                            nil]];
        });

        if (self.sharingFileIndex == self.sharedFilesArray.count)
        {
            // Last item shared
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
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
    };
    
    void (^failureBlock)(NSHTTPURLResponse *, NSError *) = ^(NSHTTPURLResponse *response, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSString *errorMessage = [self stringForStatusCode:response.statusCode];
        if (errorMessage == nil)
        {
            errorMessage = [error localizedDescription];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            errorMessage,@"error",
                                            nil]];
        });
    };
    
    [self.ocCommunication shareFileOrFolderByServer:[[self createUrlWithCredentials:NO] stringByAppendingString:@"/"]
                                andFileOrFolderPath:file.path
                                    onCommunication:self.ocCommunication
                                     successRequest:successBlock
                                     failureRequest:failureBlock];
}
#endif

#pragma mark - Download management

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
    NSProgress *progress = nil;
    
    void (^successBlock)(NSURLResponse *, NSURL *) = ^(NSURLResponse *response, NSURL *filePath) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
        });
    };
    
    void (^failureBlock)(NSURLResponse *, NSError *) = ^(NSURLResponse *response, NSError *error) {
        switch (error.code)
        {
            case kCFURLErrorUserCancelledAuthentication:
            {
                //Download cancelled
                break;
            }
            default:
            {
                NSString *errorMessage = [self stringForStatusCode:((NSHTTPURLResponse *)response).statusCode];
                if (errorMessage == nil)
                {
                    errorMessage = [error localizedDescription];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       errorMessage,@"error",
                                                       nil]];
                });
                break;
            }
        }
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.downloadTask = [self.ocCommunication downloadFileSession:[self createUrlWithPath:file.path]
                                                        toDestiny:localName
                                                  defaultPriority:YES
                                                  onCommunication:self.ocCommunication
                                                     withProgress:&progress
                                                   successRequest:successBlock
                                                   failureRequest:failureBlock];
    
    // Observe fractionCompleted using KVO
    DownloadProgressObserverContext.file_size = [file.fileSizeNumber longLongValue];
    [progress addObserver:self
               forKeyPath:@"fractionCompleted"
                  options:NSKeyValueObservingOptionNew
                  context:&DownloadProgressObserverContext];
    
}

//Method to catch the progress notifications with callbacks
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &DownloadProgressObserverContext)
    {
        //FIXME: progress incorrect
        file_ctx *ctx = (file_ctx *)context;

        if ([keyPath isEqualToString:@"fractionCompleted"] && [object isKindOfClass:[NSProgress class]]) {
            NSProgress *progress = (NSProgress *)object;
            
            long long downloaded = ctx->file_size * progress.fractionCompleted;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDownloadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithLongLong:downloaded],@"downloadedBytes",
                                                   [NSNumber numberWithLongLong:ctx->file_size],@"totalBytes",
                                                   [NSNumber numberWithDouble:progress.fractionCompleted],@"progress",
                                                   nil]];
            });
        }
    }
    else if (context == &UploadProgressObserverContext)
    {
        file_ctx *ctx = (file_ctx *)context;
        if ([keyPath isEqualToString:@"fractionCompleted"] && [object isKindOfClass:[NSProgress class]]) {
            NSProgress *progress = (NSProgress *)object;
            
            long long uploaded = ctx->file_size * progress.fractionCompleted;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithLongLong:uploaded],@"uploadedBytes",
                                                 [NSNumber numberWithLongLong:ctx->file_size],@"totalBytes",
                                                 [NSNumber numberWithDouble:progress.fractionCompleted],@"progress",
                                                 nil]];
            });
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

- (void)cancelDownloadTask
{
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    
    [self.downloadTask cancel];
}

#pragma mark - upload management

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
    NSProgress *progress = nil;
    
    void (^successBlock)(NSURLResponse *, NSString *) = ^(NSURLResponse *response, NSString *redirectedServer) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:YES],@"success",
                                             nil]];
        });
    };
    
    void (^failureBlock)(NSURLResponse *, NSString *, NSError *) = ^(NSURLResponse *response, NSString *redirectedServer, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (error.code != kCFURLErrorCancelled)
        {
            NSString *errorMessage = [self stringForStatusCode:((NSHTTPURLResponse *)response).statusCode];
            if (errorMessage == nil)
            {
                errorMessage = [error localizedDescription];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 errorMessage,@"error",
                                                 nil]];
            });
        }
    };
    
    void (^errorBeforeBlock)(NSError *) = ^(NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             [self stringForErrorCode:error],@"error",
                                             nil]];
        });
    };

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.uploadTask = [self.ocCommunication uploadFileSession:file.fullPath
                                                    toDestiny:[self createUrlWithPath:[NSString stringWithFormat:@"%@/%@",destFolder.path,file.name]]
                                              onCommunication:self.ocCommunication
                                                 withProgress:&progress
                                               successRequest:successBlock
                                               failureRequest:failureBlock
                                         failureBeforeRequest:errorBeforeBlock];
    
    // Observe fractionCompleted using KVO
    UploadProgressObserverContext.file_size = [file.fileSizeNumber longLongValue];
    [progress addObserver:self
               forKeyPath:@"fractionCompleted"
                  options:NSKeyValueObservingOptionNew
                  context:&UploadProgressObserverContext];
}

- (void)cancelUploadTask
{
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    
    [self.uploadTask cancel];
}

#pragma mark - url management

#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file
{
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.urlType = URLTYPE_HTTP;
    networkConnection.url = [NSURL URLWithString:[self createUrlWithCredentialsAndPath:[file.path encodePathString:NSUTF8StringEncoding]]];
  	return networkConnection;
}
#endif

#pragma mark - supported features

- (NSInteger)supportedFeaturesAtPath:(NSString *)path
{
    NSInteger features = CMSupportedFeaturesMaskFolderCreate   |
                         CMSupportedFeaturesMaskFileDelete     |
                         CMSupportedFeaturesMaskFolderDelete   |
                         CMSupportedFeaturesMaskDeleteCancel   |
                         CMSupportedFeaturesMaskFileRename     |
                         CMSupportedFeaturesMaskFolderRename   |
                         CMSupportedFeaturesMaskFileMove       |
                         CMSupportedFeaturesMaskFolderMove     |
                         CMSupportedFeaturesMaskMoveCancel     |
                         CMSupportedFeaturesMaskFileDownload   |
                         CMSupportedFeaturesMaskDownloadCancel |
                         CMSupportedFeaturesMaskFileUpload     |
                         CMSupportedFeaturesMaskUploadCancel   |
                         CMSupportedFeaturesMaskFileShare      |
                         CMSupportedFeaturesMaskFolderShare    |
                         CMSupportedFeaturesMaskVLCPlayer      |
                         CMSupportedFeaturesMaskQTPlayer       |
                         CMSupportedFeaturesMaskGoogleCast     |
                         CMSupportedFeaturesMaskFileDownload   |
                         CMSupportedFeaturesMaskDownloadCancel;
    return features;
}

@end
