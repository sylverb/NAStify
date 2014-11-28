//
//  CMSamba.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//
//  using samba library
//  using code from KxSMB (https://github.com/kolyvan/kxsmb)
//
//FIXME: just uploaded file returns "busy" if trying to delete it
//FIXME: crash when trying to list unreachable network (when in 3G/4G for example)

#if !(TARGET_IPHONE_SIMULATOR)
#import "CMSamba.h"
#import "NSStringAdditions.h"
#import "SBNetworkActivityIndicator.h"
#import "SSKeychain.h"

#ifdef DEBUG
#define SAMBA_DEBUG_LEVEL 2
#else
#define SAMBA_DEBUG_LEVEL 0
#endif

char c_user[255];
char c_password[255];

NSString * const KxSMBErrorDomain = @"com.sylver.NAStify";

// Prototypes

static void nastify_smbc_get_auth_data_fn(const char *srv,
                                          const char *shr,
                                          char *pworkgroup, int wglen,
                                          char *pusername, int unlen,
                                          char *ppassword, int pwlen);

// Functions

static NSString * KxSMBErrorMessage (KxSMBError errorCode)
{
    switch (errorCode) {
        case KxSMBErrorUnknown:             return NSLocalizedString(@"SMB Error", nil);
        case KxSMBErrorInvalidArg:          return NSLocalizedString(@"SMB Invalid argument", nil);
        case KxSMBErrorInvalidProtocol:     return NSLocalizedString(@"SMB Invalid protocol", nil);
        case KxSMBErrorOutOfMemory:         return NSLocalizedString(@"SMB Out of memory", nil);
        case KxSMBErrorPermissionDenied:    return NSLocalizedString(@"SMB Permission denied", nil);
        case KxSMBErrorInvalidPath:         return NSLocalizedString(@"SMB No such file or directory", nil);
        case KxSMBErrorPathIsNotDir:        return NSLocalizedString(@"SMB Not a directory", nil);
        case KxSMBErrorPathIsDir:           return NSLocalizedString(@"SMB Is a directory", nil);
        case KxSMBErrorWorkgroupNotFound:   return NSLocalizedString(@"SMB Workgroup not found", nil);
        case KxSMBErrorShareDoesNotExist:   return NSLocalizedString(@"SMB Share does not exist", nil);
        case KxSMBErrorItemAlreadyExists:   return NSLocalizedString(@"SMB Item already exists", nil);
        case KxSMBErrorDirNotEmpty:         return NSLocalizedString(@"SMB Directory not empty", nil);
        case KxSMBErrorFileIO:              return NSLocalizedString(@"SMB File I/O failure", nil);
        case KxSMBErrorBusy:                return NSLocalizedString(@"SMB Ressource busy", nil);
        case KxSMBErrorRefused:             return NSLocalizedString(@"SMB Connection refused", nil);
    }
}

static KxSMBError errnoToSMBErr(int err)
{
    switch (err) {
        case EINVAL:    return KxSMBErrorInvalidArg;
        case ENOMEM:    return KxSMBErrorOutOfMemory;
        case EACCES:    return KxSMBErrorPermissionDenied;
        case ENOENT:    return KxSMBErrorInvalidPath;
        case ENOTDIR:   return KxSMBErrorPathIsNotDir;
        case EISDIR:    return KxSMBErrorPathIsDir;
        case EPERM:     return KxSMBErrorWorkgroupNotFound;
        case ENODEV:    return KxSMBErrorShareDoesNotExist;
        case EEXIST:    return KxSMBErrorItemAlreadyExists;
        case ENOTEMPTY: return KxSMBErrorDirNotEmpty;
        case EBUSY:     return KxSMBErrorBusy;
        case ECONNREFUSED:  return KxSMBErrorRefused;
        default:        return KxSMBErrorUnknown;
    }
}

#ifndef APP_EXTENSION
static NSError *mkKxSMBError(KxSMBError error, NSString *format, ...)
{
    NSDictionary *userInfo = nil;
    NSString *reason = nil;
    
    if (format) {
        
        va_list args;
        va_start(args, format);
        reason = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
    }
    
    if (reason) {
        
        userInfo = @{
                     NSLocalizedDescriptionKey : KxSMBErrorMessage(error),
                     NSLocalizedFailureReasonErrorKey : reason
                     };
        
    } else {
        
        userInfo = @{ NSLocalizedDescriptionKey : KxSMBErrorMessage(error) };
    }
    
    return [NSError errorWithDomain:KxSMBErrorDomain
                               code:error
                           userInfo:userInfo];
}
#endif

@implementation CMSamba

#pragma mark -

- (NSString *)buildURI:(FileItem *)file
{
    NSString *uri = nil;
    
    if ([self.userAccount.server length] == 0)
    {
        // Browse from workgroups list
        if ([file.objectIds count] == 1)
        {
            uri = [NSString stringWithFormat:@"smb:/%@",file.path];
        }
        else
        {
            uri = @"smb:/";
            for (NSString *pathComponent in file.objectIds)
            {
                if (![pathComponent isEqualToString:kRootID])
                {
                    uri = [uri stringByAppendingFormat:@"/%@",pathComponent];
                }
            }
            if (file.isDir)
            {
                uri = [uri stringByAppendingString:@"/"];
            }
        }
    }
    else
    {
        uri = [NSString stringWithFormat:@"smb://%@%@",self.userAccount.server,file.path];
    }
    return uri;
}

- (NSArray *)serverInfo
{
    NSString *user = nil;
    if (self.tempUser)
    {
        user = self.tempUser;
    }
    else
    {
        user = [NSString stringWithUTF8String:c_user];
    }
    
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           [NSString stringWithFormat:NSLocalizedString(@"%@",nil), @"SMB/CIFS"],
                           [NSString stringWithFormat:NSLocalizedString(@"Workgroup: %s",nil), smbc_getWorkgroup(self.smbContext)],
                           [NSString stringWithFormat:NSLocalizedString(@"User: %@",nil), user],
                           nil];
    return serverInfo;
}

- (id)init
{
    self = [super init];
	if (self)
    {
        backgroundQueue = dispatch_queue_create("com.sylver.nastify.local.bgqueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Supported features

- (BOOL)login
{
    self.smbContext = smbc_new_context();
	if (!self.smbContext)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO],@"success",
                                    NSLocalizedString(@"Initialization failure", nil),@"error",
                                    nil]];
        });
		return YES;
    }

    if (self.tempUser != nil)
    {
        strcpy(c_user,[self.tempUser cStringUsingEncoding:NSUTF8StringEncoding]);
        strcpy(c_password, [self.tempPassword cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    else if ((self.userAccount.userName) && ([self.userAccount.userName length] != 0))
    {
        strcpy(c_user,[self.userAccount.userName cStringUsingEncoding:NSUTF8StringEncoding]);
        strcpy(c_password, [[SSKeychain passwordForService:self.userAccount.uuid account:@"password"] cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    else
    {
        strcpy(c_user,"guest");
    }
    smbc_setDebug(self.smbContext, SAMBA_DEBUG_LEVEL);
    
	smbc_setTimeout(self.smbContext, 0);
    smbc_setFunctionAuthData(self.smbContext, nastify_smbc_get_auth_data_fn);
    
	if (!smbc_init_context(self.smbContext)) {
		smbc_free_context(self.smbContext, NO);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO],@"success",
                                    NSLocalizedString(@"Initialization failure", nil),@"error",
                                    nil]];
        });
        return YES;
	}
    
    smbc_set_context(self.smbContext);

    // Return YES if we need to wait for the login answer to continue
    // This is needed if the login process if needed to build other requests
    // to include cookies or sessionId for example or to check if we can connect
	return NO;
}

- (BOOL)logout
{
    if (self.smbContext)
    {
        // fixes warning: no talloc stackframe at libsmb/cliconnect.c:2637, leaking memory
        TALLOC_CTX *frame = talloc_stackframe();
        smbc_getFunctionPurgeCachedServers(self.smbContext)(self.smbContext);
        TALLOC_FREE(frame);
        
        smbc_free_context(self.smbContext, NO);
    }
    return NO;
}

- (void)listForPath:(FileItem *)folder
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(backgroundQueue, ^(void)
    {
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        // Build SMB URI
        NSString *uri = [self buildURI:folder];
        
        // get files list
        SMBCFILE *smbFile = smbc_getFunctionOpendir(self.smbContext)(self.smbContext, uri.UTF8String);
        
        // Stop the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (smbFile)
        {
            NSMutableArray *filesOutputArray = [NSMutableArray array];
            
            struct smbc_dirent *dirent;
            
            smbc_readdir_fn readdirFn = smbc_getFunctionReaddir(self.smbContext);
            
            while((dirent = readdirFn(self.smbContext, smbFile)) != NULL)
            {
                if (!dirent->name) continue;
                if (!strlen(dirent->name)) continue;
                if (!strcmp(dirent->name, ".") || !strcmp(dirent->name, "..") || !strcmp(dirent->name, "IPC$")) continue;
                
                NSString *name = [NSString stringWithUTF8String:dirent->name];
                
                NSString *itemPath;
                if ([uri hasSuffix:@"/"])
                {
                    itemPath = [uri stringByAppendingString:name] ;
                }
                else
                {
                    itemPath = [NSString stringWithFormat:@"%@/%@", uri, name];
                }
                
                // Get file type
                NSString *type = @"";
                
                /* Is it a directory */
                BOOL isDir = NO;

                switch(dirent->smbc_type)
                {
                    case SMBC_WORKGROUP:
                    case SMBC_SERVER:
                        isDir = YES;
                        break;
                        
                    case SMBC_FILE_SHARE:
                    case SMBC_IPC_SHARE:
                    case SMBC_DIR:
                        isDir = YES;
                        break;
                        
                    case SMBC_FILE:
                        if ([[name componentsSeparatedByString:@"."] count] > 1)
                        {
                            type = [[name componentsSeparatedByString:@"."] lastObject];
                        }
                        break;
                        
                    case SMBC_PRINTER_SHARE:
                    case SMBC_COMMS_SHARE:
                    case SMBC_LINK:
                        break;
                }

                struct stat st;
                memset(&st, 0, sizeof(struct stat));
                switch (dirent->smbc_type)
                {
                    case SMBC_WORKGROUP:
                    {
                        NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:isDir],@"isdir",
                                                  name,@"filename",
                                                  nil];
                        [filesOutputArray addObject:dictItem];
                        break;
                    }
                    case SMBC_SERVER:
                    {
                        NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:isDir],@"isdir",
                                                  name,@"filename",
                                                  name,@"id",
                                                  nil];
                        [filesOutputArray addObject:dictItem];
                        break;
                    }
                    default:
                    {
                        // Start the network activity spinner
                        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                        
                        int r = smbc_getFunctionStat(self.smbContext)(self.smbContext, itemPath.UTF8String, &st);
                        
                        // Stop the network activity spinner
                        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                        
                        if (r < 0)
                        {
                            NSLog(@"get stat error on %@ : %@",name,KxSMBErrorMessage(errnoToSMBErr(errno)));
                        }
                        else
                        {
                            NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:isDir],@"isdir",
                                                      name,@"filename",
                                                      [NSNumber numberWithLongLong:st.st_size],@"filesizenumber",
                                                      name,@"id",
//                                                    @"",@"group",
//                                                    @"",@"owner",
                                                      [NSNumber numberWithBool:NO],@"iscompressed",
                                                      [NSNumber numberWithBool:YES],@"writeaccess",
                                                      [NSNumber numberWithDouble:st.st_mtime],@"date",
                                                      type,@"type",
                                                      nil];
                            [filesOutputArray addObject:dictItem];
                        }
                        break;
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
            
            smbc_getFunctionClose(self.smbContext)(self.smbContext, smbFile);
        
        }
        else
        {
//            smbc_free_context(self.smbContext, NO);
            
            const int err = errno;
            if (errno != EPERM)
            {
                NSString *error = KxSMBErrorMessage(errnoToSMBErr(err));
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                folder.path,@"path",
                                                error,@"error",
                                                nil]];
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCredentialRequest:nil];
                });
            }
        }
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(backgroundQueue, ^(void)
    {
        NSString *uri = [self buildURI:folder];
        NSString *itemPath;
        if ([uri hasSuffix:@"/"])
        {
            itemPath = [uri stringByAppendingString:folderName] ;
        }
        else
        {
            itemPath = [NSString stringWithFormat:@"%@/%@", uri, folderName];
        }

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        int r = smbc_getFunctionMkdir(self.smbContext)(self.smbContext, itemPath.UTF8String, 0);
        
        // Stop the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (r < 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                const int err = errno;
                [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               KxSMBErrorMessage(errnoToSMBErr(err)),@"error",
                                               nil]];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
        
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void)
    {
        BOOL success = YES;
        NSError *error = nil;
        
        for (FileItem *file in files)
        {
            NSString *uri = [self buildURI:file];
            // Start the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
            
            int r = smbc_getFunctionUnlink(self.smbContext)(self.smbContext, uri.UTF8String);
            
            // Stop the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            if (r < 0)
            {
                int err = errno;
                if (err == EISDIR)
                {
                    // Start the network activity spinner
                    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                    
                    r = smbc_getFunctionRmdir(self.smbContext)(self.smbContext, uri.UTF8String);
                    
                    // Stop the network activity spinner
                    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                    
                    if (r < 0)
                    {
                        int err = errno;
                        error =  mkKxSMBError(errnoToSMBErr(err),
                                              NSLocalizedString(@"Unable rmdir file:%@ (errno:%d)", nil), file.name, err);
                    }
                }
                else
                {
                    error =  mkKxSMBError(errnoToSMBErr(err),
                                           NSLocalizedString(@"Unable unlink file:%@ (errno:%d)", nil), file.name, err);
                }
            }

            if (error)
            {
                success = NO;
                break;
            }
        }
        
        if (success)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:YES],@"success",
                                                 nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [error localizedDescription],@"error",
                                                 nil]];
            });
        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}
#endif

#ifndef APP_EXTENSION
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void)
    {
        NSString *pathUri = [self buildURI:folder];
        NSString *oldUri = [pathUri stringByAppendingFormat:@"/%@",oldFile.name];
        NSString *newUri = [pathUri stringByAppendingFormat:@"/%@",newName];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        int r = smbc_getFunctionRename(self.smbContext)(self.smbContext, oldUri.UTF8String, self.smbContext, newUri.UTF8String);
        
        // Stop the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (r < 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                const int err = errno;
                [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:NO],@"success",
                                         KxSMBErrorMessage(errnoToSMBErr(err)),@"error",
                                         nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:YES],@"success",
                                         nil]];
            });
        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}
#endif

#ifndef APP_EXTENSION
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void)
    {
        BOOL success = YES;
        NSString *destUri = [self buildURI:destFolder];
        for (FileItem *file in files)
        {
            NSString *oldUri = [self buildURI:file];
            NSString *newUri = [destUri stringByAppendingFormat:@"/%@",file.name];
            
            // Start the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
            
            int r = smbc_getFunctionRename(self.smbContext)(self.smbContext, oldUri.UTF8String, self.smbContext, newUri.UTF8String);
            
            // Stop the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            if (r < 0)
            {
                success = NO;
                break;
            }
        }
        
        if (success)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                const int err = errno;
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               KxSMBErrorMessage(errnoToSMBErr(err)),@"error",
                                               nil]];
            });
        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}
#endif

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(backgroundQueue, ^(void)
    {
        self.cancelDownload = NO;
        NSFileManager *fm = [[NSFileManager alloc] init];
        [fm createFileAtPath:localName
                    contents:nil
                  attributes:nil];
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:[NSURL fileURLWithPath:localName] error:NULL];
        
        SMBCFILE *smbFile = smbc_getFunctionOpen(self.smbContext)(self.smbContext,
                                                                  [self buildURI:file].UTF8String,
                                                                  O_RDONLY,
                                                                  0);
        
        if (smbFile)
        {
            Byte buffer[32768];
            
            // Start the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
            
            smbc_read_fn readFn = smbc_getFunctionRead(self.smbContext);
            while (1)
            {
                NSInteger bytesToRead = [file.fileSizeNumber integerValue];
                NSInteger totalBytesExpectedToRead = bytesToRead;
                NSInteger totalBytesRead = 0;
                ssize_t r = 0;
                while (bytesToRead > 0)
                {
                    r = readFn(self.smbContext, smbFile, buffer, sizeof(buffer));
                    if ((r == 0) || (self.cancelDownload == YES))
                    {
                        break;
                    }
                    if (r < 0)
                    {
                        const int err = errno;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                               [NSNumber numberWithBool:NO],@"success",
                                                               KxSMBErrorMessage(errnoToSMBErr(err)),@"error",
                                                               nil]];
                        });
                        self.cancelDownload = YES;
                        break;
                    }
                    
                    bytesToRead -= r;
                    totalBytesRead += r;
                    @try
                    {
                        [fileHandle writeData:[NSData dataWithBytes:buffer length:r]];
                    }
                    @catch (NSException *exception)
                    {
                        self.cancelDownload = YES;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithBool:NO],@"success",
                                                             [exception description],@"error",
                                                             nil]];
                        });
                        break;
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMDownloadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithLongLong:totalBytesRead],@"downloadedBytes",
                                                           file.fileSizeNumber,@"totalBytes",
                                                           [NSNumber numberWithFloat:(float)((float)totalBytesRead/(float)totalBytesExpectedToRead)],@"progress",
                                                           nil]];
                    });
                }
                [fileHandle closeFile];
                if (self.cancelDownload == NO)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:YES],@"success",
                                                           nil]];
                    });
                }
                break;
            }
            // Stop the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        }
        else
        {
            const int err = errno;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   KxSMBErrorMessage(errnoToSMBErr(err)),@"error",
                                                   nil]];
            });
        }
        
        if (self.cancelDownload == YES)
        {
            // Delete partially donwloaded file
            [fm removeItemAtPath:localName error:NULL];
        }
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

- (void)cancelDownloadTask
{
    self.cancelDownload = YES;
}

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(backgroundQueue, ^(void)
    {
        NSLog(@"local file : %@",file.fullPath);
        
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingFromURL:[NSURL fileURLWithPath:file.fullPath] error:NULL];

        smbc_write_fn writeFn = smbc_getFunctionWrite(self.smbContext);
        
        NSLog(@"%@",[[self buildURI:destFolder] stringByAppendingString:file.name]);
        SMBCFILE *smbFile = smbc_getFunctionCreat(self.smbContext)(self.smbContext,
                                                            [[self buildURI:destFolder] stringByAppendingString:file.name].UTF8String,
                                                            O_WRONLY|O_CREAT|(overwrite ? O_TRUNC : O_EXCL));

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        while (1)
        {
            NSData *data = nil;
            @try
            {
                data = [fileHandle readDataOfLength:256*1024];
            }
            @catch (NSException *exception)
            {
                [fileHandle closeFile];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     [exception description],@"error",
                                                     nil]];
                });
                // Stop the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                return;
            }
            // read data = fileHandle.offsetInFile
            NSInteger bytesToWrite = data.length;
            const Byte *bytes = data.bytes;
            if ((bytesToWrite == 0) || (self.cancelUpload == YES))
            {
                // end of file or cancel request
                break;
            }
            while (bytesToWrite > 0)
            {
                ssize_t r = writeFn(self.smbContext, smbFile, bytes, bytesToWrite);
                NSLog(@"written %zd",r);
                if (r == 0)
                {
                    break;
                }
                if (r < 0)
                {
                    self.cancelUpload = YES;
                    const int err = errno;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         KxSMBErrorMessage(errnoToSMBErr(err)),@"error",
                                                         nil]];
                    });
                    break;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMUploadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithLongLong:fileHandle.offsetInFile],@"uploadedBytes",
                                                         file.fileSizeNumber,@"totalBytes",
                                                         [NSNumber numberWithFloat:(float)((float)fileHandle.offsetInFile/(float)([file.fileSizeNumber longLongValue]))],@"progress",
                                                         nil]];
                });

                bytesToWrite -= r;
                bytes += r;
            }
        }
        // Stop the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (self.cancelUpload == NO)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:YES],@"success",
                                                 nil]];
            });
        }
        else
        {
            //FIXME: Delete partially uploaded file
        }
        [fileHandle closeFile];
        
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

- (void)cancelUploadTask
{
    self.cancelUpload = YES;
}

- (void)setCredential:(NSString *)user password:(NSString *)password
{
    self.tempUser = user;
    self.tempPassword = password;
}

- (NetworkConnection *)urlForFile:(FileItem *)file
{
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
  	return networkConnection;
}

/* Server features */
- (NSInteger)supportedFeaturesAtPath:(NSString *)path
{
    NSInteger features = (
                          CMSupportedFeaturesMaskFileDelete      |
                          CMSupportedFeaturesMaskFolderDelete    |
                          CMSupportedFeaturesMaskFolderCreate    |
                          CMSupportedFeaturesMaskFileRename      |
                          CMSupportedFeaturesMaskFolderRename    |
                          CMSupportedFeaturesMaskFileMove        |
                          CMSupportedFeaturesMaskFolderMove      |
                          CMSupportedFeaturesMaskFileDownload    |
                          CMSupportedFeaturesMaskDownloadCancel  |
                          CMSupportedFeaturesMaskFileUpload      |
                          CMSupportedFeaturesMaskUploadCancel    |
                          CMSupportedFeaturesMaskVideoSeek       |
                          CMSupportedFeaturesMaskAirPlay
                          );
    return features;
}

@end

static void nastify_smbc_get_auth_data_fn(const char *srv,
                                          const char *shr,
                                          char *pworkgroup, int wglen,
                                          char *pusername, int unlen,
                                          char *ppassword, int pwlen)
{
    strncpy(pusername, c_user, unlen - 1);
    strncpy(ppassword, c_password, pwlen - 1);
}
#endif
