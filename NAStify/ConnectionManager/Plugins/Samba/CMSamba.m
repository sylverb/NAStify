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

#if 0
#import "CMSamba.h"
#import "NSStringAdditions.h"
#import "SBNetworkActivityIndicator.h"
#import "SSKeychain.h"

#define SAMBA_DEBUG_LEVEL 2

NSString * const KxSMBErrorDomain = @"com.sylver.NAStify";

// Prototypes

static void my_smbc_get_auth_data_fn(const char *srv,
                                     const char *shr,
                                     char *workgroup, int wglen,
                                     char *username, int unlen,
                                     char *password, int pwlen);

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
        default:        return KxSMBErrorUnknown;
    }
}

static NSError * mkKxSMBError(KxSMBError error, NSString *format, ...)
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

@implementation CMSamba

#pragma mark -

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
    smbContext = smbc_new_context();
	if (!smbContext)
		return NULL;
    
#ifdef DEBUG
    smbc_setDebug(smbContext, SAMBA_DEBUG_LEVEL);
#else
    smbc_setDebug(smbContext, 0);
#endif
    
	smbc_setTimeout(smbContext, 0);
    smbc_setFunctionAuthData(smbContext, my_smbc_get_auth_data_fn);
    
	if (!smbc_init_context(smbContext)) {
		smbc_free_context(smbContext, NO);
		return NULL;
	}
    
    smbc_set_context(smbContext);

    // Return YES if we need to wait for the login answer to continue
    // This is needed if the login process if needed to build other requests
    // to include cookies or sessionId for example or to check if we can connect
	return NO;
}

- (BOOL)logout
{
    if (smbContext) {
        
        // fixes warning: no talloc stackframe at libsmb/cliconnect.c:2637, leaking memory
        TALLOC_CTX *frame = talloc_stackframe();
        smbc_getFunctionPurgeCachedServers(smbContext)(smbContext);
        TALLOC_FREE(frame);
        
        smbc_free_context(smbContext, NO);
    }
    return NO;
}

- (void)listForPath:(FileItem *)folder
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void)
    {
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        // get files list
        NSLog(@"Get file at %@",[NSString stringWithFormat:@"smb://192.168.1.10%@",folder.path]);
        SMBCFILE *smbFile = smbc_getFunctionOpendir(smbContext)(smbContext, [NSString stringWithFormat:@"smb://192.168.1.10%@",folder.path].UTF8String);
        
        // Stop the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (smbFile)
        {
            NSMutableArray *filesOutputArray = [NSMutableArray array];
            
            struct smbc_dirent *dirent;
            
            smbc_readdir_fn readdirFn = smbc_getFunctionReaddir(smbContext);
            
            while((dirent = readdirFn(smbContext, smbFile)) != NULL) {
                
                if (!dirent->name) continue;
                if (!strlen(dirent->name)) continue;
                if (dirent->name[0] == '.') continue;
                if (!strcmp(dirent->name, "IPC$")) continue;
                
                NSString *name = [NSString stringWithUTF8String:dirent->name];
                
                NSString *itemPath;
                if ([folder.path hasSuffix:@"/"])
                    itemPath = [folder.path stringByAppendingString:name] ;
                else
                    itemPath = [NSString stringWithFormat:@"%@/%@", folder.path, name];

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
                if (dirent->smbc_type != SMBC_WORKGROUP &&
                    dirent->smbc_type != SMBC_SERVER)
                {
                    int r = smbc_getFunctionStat(smbContext)(smbContext, [NSString stringWithFormat:@"smb://192.168.1.10%@",itemPath].UTF8String, &st);
                    if (r < 0)
                    {
                        NSLog(@"get stat error %@",KxSMBErrorMessage(errnoToSMBErr(errno)));
                    }
                    else
                    {
                        NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:isDir],@"isdir",
                                                  name,@"filename",
                                                  [NSNumber numberWithLongLong:st.st_size],@"filesizenumber",
//                                                  @"",@"group",
//                                                  @"",@"owner",
                                                  [NSNumber numberWithBool:NO],@"iscompressed",
                                                  [NSNumber numberWithBool:!(st.st_mode & SMBC_DOS_MODE_READONLY)],@"writeaccess",
                                                  [NSNumber numberWithDouble:st.st_mtime],@"date",
                                                  type,@"type",
                                                  nil];
                        [filesOutputArray addObject:dictItem];
                    }
                }
            }
            
            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES],@"success",
                                        folder.path,@"path",
                                        filesOutputArray,@"filesList",
                                        nil]];
            
            smbc_getFunctionClose(smbContext)(smbContext, smbFile);
        
        }
        else
        {
            NSString *error = KxSMBErrorMessage(errnoToSMBErr(errno));
            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        folder.path,@"path",
                                        error,@"error",
                                        nil]];
        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
{
#if 0
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void)
    {
        int ret;
        NSString *fullPath = [NSString stringWithFormat:@"%@/%@",path,folder];
        const char *spath = [[fullPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
        ret = ne_mkcol(self.webDavSession, spath);
        
        if (!ret)
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
                                               [error description],@"error",
                                               nil]];
            });
        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
#endif
}

- (void)deleteFiles:(NSArray *)files
{
#if 0
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void)
    {
        int ret;
        BOOL success = YES;
        for (FileItem *file in files)
        {
            const char *spath = [[file.path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
            ret = ne_delete(self.webDavSession, spath);
            if (ret)
            {
                success = NO;
                break;
            }
        }
        
        if (success)
        {
            NSNotification *notification = [NSNotification notificationWithName:NotificationName(CMDELETEFINISHED)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                 [NSNumber numberWithBool:YES],@"success",
                                                                                 nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        else
        {
            NSNotification *notification = [NSNotification notificationWithName:NotificationName(CMDELETEFINISHED)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                 [NSNumber numberWithBool:NO],@"success",
                                                                                 [NSString stringWithFormat:@"Error code : %d",ret],@"error",
                                                                                 nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
#endif
}

- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
#if 0
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void)
    {
        int ret;
        NSString *fullSrcName = [NSString stringWithFormat:@"%@/%@",path.path,oldName];
        NSString *fullDestName = [NSString stringWithFormat:@"%@/%@",path.path,newName];
        const char *sname = [[fullSrcName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
        const char *dname = [[fullDestName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
        
        ret = ne_move(self.webDavSession, FALSE, sname, dname);
        if (!ret)
        {
            NSNotification *notification = [NSNotification notificationWithName:NotificationName(CMRENAMEFINISHED)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                 [NSNumber numberWithBool:YES],@"success",
                                                                                 nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        else
        {
            NSNotification *notification = [NSNotification notificationWithName:NotificationName(CMRENAMEFINISHED)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                 [NSNumber numberWithBool:NO],@"success",
                                                                                 [NSString stringWithFormat:@"Error code : %d",ret],@"error",
                                                                                 nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
#endif
}

- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
#if 0
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void)
    {
        int ret;
        BOOL success = YES;
        for (FileItem *file in files)
        {
            NSString *fullDestPath = [NSString stringWithFormat:@"%@/%@",toPath,file.name];
            const char *spath = [[file.path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
            const char *dpath = [[fullDestPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
            ret = ne_move(self.webDavSession, overwrite, spath, dpath);
            if (ret)
            {
                success = NO;
                break;
            }
        }
        
        if (success)
        {
            NSNotification *notification = [NSNotification notificationWithName:NotificationName(CMMOVEFINISHED)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                 [NSNumber numberWithBool:YES],@"success",
                                                                                 nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        else
        {
            NSNotification *notification = [NSNotification notificationWithName:NotificationName(CMMOVEFINISHED)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                 [NSNumber numberWithBool:NO],@"success",
                                                                                 [NSString stringWithFormat:@"Error code : %d",ret],@"error",
                                                                                 nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
#endif
}

- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
#if 0
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void)
    {
        int ret;
        BOOL success = YES;
        for (FileItem *file in files)
        {
            NSString *fullDestPath = [NSString stringWithFormat:@"%@/%@",toPath,file.name];
            const char *spath = [[file.path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
            const char *dpath = [[fullDestPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
            ret = ne_copy(self.webDavSession, overwrite, NE_DEPTH_INFINITE, spath, dpath);
            if (ret)
            {
                success = NO;
                break;
            }
        }
        
        if (success)
        {
            NSNotification *notification = [NSNotification notificationWithName:NotificationName(CMCOPYFINISHED)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                 [NSNumber numberWithBool:YES],@"success",
                                                                                 nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        else
        {
            NSNotification *notification = [NSNotification notificationWithName:NotificationName(CMCOPYFINISHED)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                 [NSNumber numberWithBool:NO],@"success",
                                                                                 [NSString stringWithFormat:@"Error code : %d",ret],@"error",
                                                                                 nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
#endif
}

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
#if 0
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void)
    {
        // Go to documents folder
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *localPath = [[paths objectAtIndex:0] stringByAppendingFormat:@"/%@",localName];
        int ret;
        
        size_t downloaded = 0;
        get_context ctx;
        ctx.session = self.webDavSession;
        ctx.error = 0;
        ctx.file = [localPath UTF8String];
        ctx.fd = 0;
        ctx.totalDownloaded = &downloaded;
        
        char *spath = ne_path_escape([file.path UTF8String]);
        ne_request *req = ne_request_create(self.webDavSession, "GET", spath);
        
        ne_add_response_body_reader(req, ne_accept_2xx, file_reader, &ctx);
        
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                         0, 0, dispatch_get_main_queue());
        long long totalSize = [file.fileSizeNumber longLongValue];
        if (timer)
        {
            dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), 100 * USEC_PER_SEC,  100 * USEC_PER_SEC);
            dispatch_source_set_event_handler(timer, ^{
                NSNotification* notification = [NSNotification notificationWithName:NotificationName(CMDOWNLOADPROGRESS)
                                                                             object:self
                                                                           userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                     [NSNumber numberWithLongLong:*(ctx.totalDownloaded)],@"downloadedBytes",
                                                                                     file.fileSizeNumber,@"totalBytes",
                                                                                     [NSNumber numberWithFloat:(float)((float)*(ctx.totalDownloaded)/(float)totalSize)],@"progress",
                                                                                     nil]];
                [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:)
                                                                       withObject:notification
                                                                    waitUntilDone:YES];
                
            });
            dispatch_resume(timer);
        }
        ret = ne_request_dispatch(req);
        
        ne_request_destroy(req);
        if (ctx.fd > 0)
        {
            close(ctx.fd);
        }
        
        if (!ret)
        {
            NSNotification *notification = [NSNotification notificationWithName:NotificationName(CMDOWNLOADFINISHED)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                 [NSNumber numberWithBool:YES],@"success",
                                                                                 nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        else
        {
            NSNotification *notification = [NSNotification notificationWithName:NotificationName(CMDOWNLOADFINISHED)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                 [NSNumber numberWithBool:NO],@"success",
                                                                                 [[NSString alloc] initWithUTF8String:ne_get_error(self.webDavSession)],@"error",
                                                                                 nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];

        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
#endif
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
                          CMSupportedFeaturesMaskFileCopy        |
                          CMSupportedFeaturesMaskFolderCopy      |
                          CMSupportedFeaturesMaskFileDownload    |
                          CMSupportedFeaturesMaskFileUpload      |
                          CMSupportedFeaturesMaskVideoSeek       |
                          CMSupportedFeaturesMaskAirPlay
                          );
    return features;
}

@end

static void my_smbc_get_auth_data_fn(const char *srv,
                                     const char *shr,
                                     char *workgroup, int wglen,
                                     char *username, int unlen,
                                     char *password, int pwlen)
{
    strncpy(username, "username", unlen - 1);
    strncpy(password, "password", pwlen - 1);
    strncpy(workgroup, "WORKGROUP", wglen - 1);
//    strncpy(username, "guest", unlen - 1);
//    password[0] = 0;
    workgroup[0] = 0;
    
//    NSLog(@"smb get auth for %s/%s -> %s/%s:%s", srv, shr, workgroup, username, password);
}
#endif
