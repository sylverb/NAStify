//
//  CMWebDav.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//
//  using neon library (http://www.webdav.org/neon/)
//  using some code from davfs2 (http://savannah.nongnu.org/projects/davfs2)
//
//  Known issue : crash if doing a logout while a connection is running 
//  Known issue : crash if doing a logout while downloading
//  TODO : get errors from neon correctly
//  TODO : get WebDAV hidden status (if really needed ?)

#import "CMWebDav.h"

#import "NSStringAdditions.h"
#import "SBNetworkActivityIndicator.h"
#import "SSKeychain.h"
#include <sys/stat.h>

typedef struct {
    char username[255];     /* Username for server authentication */
    char password[255];     /* Password for server authentication */
} auth_creds_context;

typedef struct {
    BOOL *trustedcertificate;
} ssl_verify_context;

typedef struct {
    ne_session *session;
    // Server info
    const char *scheme;
    const char *host;
    int port;
} cookie_context;

/* functions prototypes */
static int ssl_verify_callback(void *userdata, int failures, const ne_ssl_certificate *cert);
static int auth_creds_callback(void *userdata, const char *realm, int attempts, char *username, char *password);

/* Session cookie. */
static char *cookie;
static void add_header(ne_request *req, void *userdata, ne_buffer *header);
static int update_cookie_callback(ne_request *req, void *userdata, const ne_status *status);

/* list parsing */
enum {
    ETAG = 0,
    LENGTH,
    CREATION,
    MODIFIED,
    TYPE,
    EXECUTE,
    END
};

static const ne_propname prop_names[] = {
    [ETAG] = {"DAV:", "getetag"},
    [LENGTH] = {"DAV:", "getcontentlength"},
    [CREATION] ={"DAV:", "creationdate"},
    [MODIFIED] = {"DAV:", "getlastmodified"},
    [TYPE] = {"DAV:", "resourcetype"},
    [EXECUTE] = {"http://apache.org/dav/props/", "executable"},
    [END] = {NULL, NULL}
};

static const ne_propname anonymous_prop_names[] = {
    [ETAG] = {NULL, "getetag"},
    [LENGTH] = {NULL, "getcontentlength"},
    [CREATION] ={NULL, "creationdate"},
    [MODIFIED] = {NULL, "getlastmodified"},
    [TYPE] = {NULL, "resourcetype"},
    [EXECUTE] = {NULL, "executable"},
    [END] = {NULL, NULL}
};

typedef struct dav_props dav_props;
struct dav_props {
    char *path;         /* The unescaped path of the resource. */
    char *name;         /* The name of the file or directory. Only the last
                         component (no path), no slashes. */
    char *etag;         /* The etag string, including quotation characters,
                         but without the mark for weak etags. */
    off_t size;         /* File size in bytes (regular files only). */
    time_t ctime;       /* Creation date. */
    time_t mtime;       /* Date of last modification. */
    int is_dir;         /* Boolean; 1 if a directory. */
    int is_exec;        /* -1 if not specified; 1 is executeable;
                         0 not executeable. */
    dav_props *next;    /* Next in the list. */
};

typedef struct {
    const char *path;           /* The *not* url-encoded path. */
    dav_props *results;         /* Start of the linked list of dav_props. */
} propfind_context;

static void prop_result_callback(void *userdata, const ne_uri *uri, const ne_prop_result_set *set);
static void dav_delete_props(dav_props *props);

@implementation CMWebDav

#pragma mark -

- (id)init
{
    self = [super init];
	if (self)
    {
        trustedCert = YES;
        backgroundQueue = dispatch_queue_create("com.sylver.nastify.local.bgqueue", NULL);
    }
    return self;
}

#pragma mark - Supported features

- (NSString *)createFullPath:(NSString *)path
{
    NSString *fullPath = nil;
    if ([self.userAccount.settings objectForKey:@"path"])
    {
        fullPath = [self.userAccount.settings objectForKey:@"path"];
        while ([fullPath hasSuffix:@"/"])
        {
            fullPath = [fullPath substringToIndex:[fullPath length]-1];
        }
        fullPath = [fullPath stringByAppendingString:path];
    }
    else
    {
        fullPath = path;
    }
    return fullPath;
}

- (NSString *)createRootURLString
{
    NSArray *urlArray = [self.userAccount.server componentsSeparatedByString:@"/"];
    NSInteger ipIndex = 0;
    if ([urlArray count] > 1)
    {
        // If we have an entry with several elements
        if ([[urlArray objectAtIndex:0] isEqualToString:@"http:"] ||
            [[urlArray objectAtIndex:0] isEqualToString:@"https:"] ||
            [[urlArray objectAtIndex:0] isEqualToString:@"webdav:"] ||
            [[urlArray objectAtIndex:0] isEqualToString:@"webdavs:"])
        {
            // First object is http/https/webdav/webdavs
            ipIndex = 2;
        }
    }
    
	NSMutableString * url = [NSMutableString string];
    if (ipIndex == 0)
    {
        if (self.userAccount.boolSSL)
        {
            [url setString:@"https://"];
        }
        else
        {
            [url setString:@"http://"];
        }
    }
    else if ([[urlArray objectAtIndex:0] isEqualToString:@"webdav:"])
    {
        [url setString:@"http://"];
    }
    else if ([[urlArray objectAtIndex:0] isEqualToString:@"webdavs:"])
    {
        [url setString:@"https://"];
    }
    else
    {
        [url appendFormat:@"%@//",[urlArray objectAtIndex:0]];
    }
	[url appendString:[urlArray objectAtIndex:ipIndex]];
    
	NSString *port = self.userAccount.port;
	if ((port) && !([port length] == 0))
    {
        [url appendFormat:@":%@", port];
	}

    NSInteger i;
    for (i = ipIndex + 1; i < [urlArray count]; i++)
    {
        [url appendFormat:@"/%@",[urlArray objectAtIndex:i]];
    }
    
	return url;
}

- (NSString *)createRootURLStringWithCredentials {
    NSArray *urlArray = [self.userAccount.server componentsSeparatedByString:@"/"];
    NSInteger ipIndex = 0;
    if ([urlArray count] > 1)
    {
        // If we have an entry with several elements
        if ([[urlArray objectAtIndex:0] isEqualToString:@"http:"] ||
            [[urlArray objectAtIndex:0] isEqualToString:@"https:"] ||
            [[urlArray objectAtIndex:0] isEqualToString:@"webdav:"] ||
            [[urlArray objectAtIndex:0] isEqualToString:@"webdavs:"])
        {
            // First object is http/https/webdav/webdavs
            ipIndex = 2;
        }
    }
    
	NSMutableString * url = [NSMutableString stringWithCapacity:10];
    if (ipIndex == 0)
    {
        if (self.userAccount.boolSSL)
        {
            [url setString:@"https://"];
        }
        else
        {
            [url setString:@"http://"];
        }
    }
    else if ([[urlArray objectAtIndex:0] isEqualToString:@"webdav:"])
    {
        [url setString:@"http://"];
    }
    else if ([[urlArray objectAtIndex:0] isEqualToString:@"webdavs:"])
    {
        [url setString:@"https://"];
    }
    else
    {
        [url appendFormat:@"%@//",[urlArray objectAtIndex:0]];
    }
    
    NSString *password = [SSKeychain passwordForService:self.userAccount.uuid
                                                account:@"password"];
    // Add credentials
    [url appendFormat:@"%@:%@@", self.userAccount.userName, password];
    
	[url appendString:[urlArray objectAtIndex:ipIndex]];
    
	NSString *port = self.userAccount.port;
	if ((port == nil) || ([port length] == 0))
    {
		if (self.userAccount.boolSSL)
        {
			port = @"443";
        }
		else
        {
			port = @"80";
        }
	}
    [url appendFormat:@":%@", port];
    
    NSInteger i;
    for (i = ipIndex + 1; i < [urlArray count]; i++)
    {
        [url appendFormat:@"/%@",[urlArray objectAtIndex:i]];
    }
    
	return url;
}

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           NSLocalizedString(@"Server Type : WebDAV",nil),
                           nil];
    return serverInfo;
}

- (BOOL)login
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(backgroundQueue, ^(void) {
        BOOL loginOk = YES;
        NSString *errorString = [NSString string];
        
        const char *scheme;
        int port;
        
        if (self.userAccount.boolSSL)
        {
            scheme = "https";
        }
        else
        {
            scheme = "http";
        }
        
        NSString *serverString = [[NSURL URLWithString:[self createRootURLString]] host];
        
        NSLog(@"%s\n",ne_version_string());
        
        if (ne_sock_init())
        {
            loginOk = NO;
            errorString = [errorString stringByAppendingString:@"initialization of neon library failed\n"];
        }
        else
        {
            if ((self.userAccount.port == nil) || ([self.userAccount.port length] == 0))
            {
                if (strcmp(scheme, "https") == 0)
                {
                    port = 443;
                }
                else
                {
                    port = 80;
                }
            }
            else
            {
                port = [self.userAccount.port intValue];
            }
            
            // Create neon session for this server
            self.webDavSession = ne_session_create(scheme, [serverString UTF8String], port);
            
            // Authentication configuration
            NSString *password = [SSKeychain passwordForService:self.userAccount.uuid account:@"password"];
            if (password == nil)
            {
                password = @"";
            }
            
            auth_creds_context auth_ctx;
            strcpy(auth_ctx.username, ne_strdup([self.userAccount.userName UTF8String]));
            strcpy(auth_ctx.password, ne_strdup([password UTF8String]));
            ne_add_server_auth(self.webDavSession, NE_AUTH_ALL, auth_creds_callback, &auth_ctx);
            
            // If SSL connection requested, configure certificate verification
            if (self.userAccount.boolSSL)
            {
                ssl_verify_context ssl_verify_ctx;
                
                ssl_verify_ctx.trustedcertificate = &trustedCert;
                
                ne_ssl_set_verify(self.webDavSession, ssl_verify_callback, &ssl_verify_ctx);
                ne_ssl_trust_default_ca(self.webDavSession);
            }
            
            // Cookies handling
            cookie_context cookie_ctx;
            cookie_ctx.session = self.webDavSession;
            cookie_ctx.scheme = scheme;
            cookie_ctx.host = [serverString UTF8String];
            cookie_ctx.port = port;

            ne_hook_post_send(self.webDavSession, update_cookie_callback, &cookie_ctx);
            
            // Start the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
            
            unsigned int caps;
            int ret = ne_options2(self.webDavSession, [self createFullPath:@"/"].UTF8String, &caps);

            // Stop the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

            if (ret == NE_OK)
            {
                if (!((caps & NE_CAP_DAV_CLASS1) == NE_CAP_DAV_CLASS1))
                {
                    loginOk = NO;
                    errorString = [errorString stringByAppendingString:@"this is not a WebDAV server\n"];
                }
            }
            else
            {
                loginOk = NO;
                errorString = [errorString stringByAppendingFormat:@"%@",[[NSString alloc] initWithUTF8String:ne_get_error(self.webDavSession)]];
            }
            
            if ((self.userAccount.boolSSL) && (!trustedCert) && (!self.userAccount.acceptUntrustedCertificate))
            {
                loginOk = NO;
                errorString = [errorString stringByAppendingString:@"Server's certificate is untrusted\n"];
            }
        }
        if (loginOk)
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
                                        errorString,@"error",
                                        nil]];
            });
        }
        
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
    
    // Return YES if we need to wait for the login answer to continue
    // This is needed if the login process if needed to build other requests
    // to include cookies or sessionId for example or to check if we can connect
	return YES;
}

- (BOOL)logout
{
    if (self.webDavSession)
    {
        ne_close_connection(self.webDavSession);
        ne_session_destroy(self.webDavSession);
        self.webDavSession = NULL;
    }
    ne_sock_exit();

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
        int ret;
        
        propfind_context ctx;
        ctx.path = [[self createFullPath:folder.path] UTF8String];
        ctx.results = NULL;
        
        const char *spath = [[[self createFullPath:folder.path] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
        ne_propfind_handler *propfind_handler = ne_propfind_create(self.webDavSession, spath, NE_DEPTH_ONE);
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

        ret = ne_propfind_named(propfind_handler, prop_names, prop_result_callback, &ctx);

        ne_propfind_destroy(propfind_handler);

        // Stop the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (!ret)
        {
            NSMutableArray *filesOutputArray = [NSMutableArray array];
            
            while(ctx.results) {
                dav_props *tofree = ctx.results;
                ctx.results = ctx.results->next;
                
                if (strcmp(tofree->name, "") != 0)
                {
                    // Get filename
                    NSString *fileName = [NSString stringWithUTF8String:tofree->name];
                    
                    // Get file type
                    NSString *type = @"";
                    if ([[fileName componentsSeparatedByString:@"."] count] > 1)
                    {
                        type = [[fileName componentsSeparatedByString:@"."] lastObject];
                    }
                    
                    /* Is it a directory */
                    BOOL isDir = tofree->is_dir;
                    
                    NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithBool:isDir],@"isdir",
                                              [[fileName componentsSeparatedByString:@"/"] lastObject],@"filename",
                                              [NSNumber numberWithLongLong:tofree->size],@"filesizenumber",
                                              [NSNumber numberWithBool:NO],@"iscompressed",
                                              [NSNumber numberWithBool:YES],@"writeaccess",
                                              [NSNumber numberWithDouble:tofree->mtime],@"date",
                                              type,@"type",
                                              nil];
                    [filesOutputArray addObject:dictItem];
                }
                // free element
                dav_delete_props(tofree);
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
                                            [[NSString alloc] initWithUTF8String:ne_get_error(self.webDavSession)],@"error",
                                            nil]];
            });
        }
        
        // Clear results
        while(ctx.results)
        {
            dav_props *tofree = ctx.results;
            ctx.results = ctx.results->next;
            dav_delete_props(tofree);
        }
        
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(backgroundQueue, ^(void)
    {
        int ret;
        NSString *fullPath = [self createFullPath:[NSString stringWithFormat:@"%@/%@",folder.path,folderName]];
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
                                               [[NSString alloc] initWithUTF8String:ne_get_error(self.webDavSession)],@"error",
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
        int ret;
        BOOL success = YES;
        for (FileItem *file in files)
        {
            const char *spath = [[[self createFullPath:file.path] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
            ret = ne_delete(self.webDavSession, spath);
            if (ret)
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
                                                 [[NSString alloc] initWithUTF8String:ne_get_error(self.webDavSession)],@"error",
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
        int ret;
        NSString *fullSrcName = [self createFullPath:[NSString stringWithFormat:@"%@/%@",folder.path,oldFile.name]];
        NSString *fullDestName = [self createFullPath:[NSString stringWithFormat:@"%@/%@",folder.path,newName]];
        const char *sname = [[fullSrcName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
        const char *dname = [[fullDestName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
        
        ret = ne_move(self.webDavSession, FALSE, sname, dname);
        if (!ret)
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
                                         [[NSString alloc] initWithUTF8String:ne_get_error(self.webDavSession)],@"error",
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
        int ret;
        BOOL success = YES;
        for (FileItem *file in files)
        {
            NSString *fullDestPath = [NSString stringWithFormat:@"%@/%@",destFolder.path,file.name];
            const char *spath = [[[self createFullPath:file.path] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
            const char *dpath = [[[self createFullPath:fullDestPath] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
            ret = ne_move(self.webDavSession, overwrite, spath, dpath);
            if (ret)
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
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [[NSString alloc] initWithUTF8String:ne_get_error(self.webDavSession)],@"error",
                                               nil]];
            });
        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}
#endif

#ifndef APP_EXTENSION
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
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
            NSString *fullDestPath = [NSString stringWithFormat:@"%@/%@",destFolder.path,file.name];
            const char *spath = [[[self createFullPath:file.path] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
            const char *dpath = [[[self createFullPath:fullDestPath] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String];
            ret = ne_copy(self.webDavSession, overwrite, NE_DEPTH_INFINITE, spath, dpath);
            if (ret)
            {
                success = NO;
                break;
            }
        }
        
        if (success)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [[NSString alloc] initWithUTF8String:ne_get_error(self.webDavSession)],@"error",
                                               nil]];
            });
        }
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}
#endif

#pragma mark - download management

typedef struct {
    ne_session *session;        /* pointer to current session */
    int error;                  /* An error occured while reading/writing. */
    const char *file;           /* cache_file to store the data in. */
    size_t *totalDownloaded;    /* total downloaded */
    size_t *totalUploaded;      /* total uploaded */
    int fd;                     /* file descriptor of the open cache file. */
} get_context;

static int
file_reader(void *userdata, const char *block, size_t length)
{
    get_context *ctx = (get_context *) userdata;
    
    // If file is not aleady opened, open it
    if (!ctx->fd)
        ctx->fd = open(ctx->file,
                       O_CREAT | O_WRONLY | O_TRUNC,
                       S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH); // 666
    if (ctx->fd <= 0) {
        ne_set_error(ctx->session, "Unable to open destination file : %d",ctx->fd);
        ctx->error = EIO;
    }
    
    // Write received bytes in the files 
    while (!ctx->error && length > 0) {
        *(ctx->totalDownloaded) += length;
        ssize_t ret = write(ctx->fd, block, length);
        if (ret < 0) {
            ne_set_error(ctx->session, "Unable to write in destination file : %zd",ret);
            ctx->error = EIO;
        } else {
            length -= ret;
            block += ret;
        }
    }
    
    return ctx->error;
}

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
        BOOL use_compression = ne_has_support(NE_FEATURE_ZLIB);
        
        int ret;
        
        size_t downloaded = 0;
        get_context ctx;
        ctx.session = self.webDavSession;
        ctx.error = 0;
        ctx.file = [localName UTF8String];
        ctx.fd = 0;
        ctx.totalDownloaded = &downloaded;
        
        NSString *destPath = [self createFullPath:file.path];

        char *spath = ne_path_escape([destPath UTF8String]);
        ne_request *req = ne_request_create(self.webDavSession, "GET", spath);
        
        ne_decompress *dc_state = NULL;
        if (use_compression)
        {
            dc_state = ne_decompress_reader(req, ne_accept_2xx, file_reader, &ctx);
        }
        else
        {
            ne_add_response_body_reader(req, ne_accept_2xx, file_reader, &ctx);
        }
        
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                         0, 0, dispatch_get_main_queue());
        long long totalSize = [file.fileSizeNumber longLongValue];
        if (timer)
        {
            dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), 100 * USEC_PER_SEC,  100 * USEC_PER_SEC);
            dispatch_source_set_event_handler(timer, ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDownloadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithLongLong:*(ctx.totalDownloaded)],@"downloadedBytes",
                                                       file.fileSizeNumber,@"totalBytes",
                                                       [NSNumber numberWithFloat:(float)((float)*(ctx.totalDownloaded)/(float)totalSize)],@"progress",
                                                       nil]];
                });
            });
            dispatch_resume(timer);
        }
        ret = ne_request_dispatch(req);
        
        if (use_compression)
        {
            ne_decompress_destroy(dc_state);
        }
        
        const ne_status *status = ne_get_status(req);
        if ((!ret) && (status->code == 200))
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
                                                   [[NSString alloc] initWithUTF8String:ne_get_error(self.webDavSession)],@"error",
                                                   nil]];
            });
        }
        
        ne_request_destroy(req);
        
        if (ctx.fd > 0)
        {
            close(ctx.fd);
        }
        free(spath);
        
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

#pragma mark - upload management

void status(void *userdata, ne_session_status status,
                         const ne_session_status_info *info)
{
    get_context *ctx = (get_context *) userdata;

    switch (status)
    {
        case ne_status_sending:
        {
            // update uploaded bytes
            *(ctx->totalUploaded) = (size_t)info->sr.progress;
            break;
        }
        default:
        {
            break;
        }
    }
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
        int ret;
        
        size_t uploaded = 0;
        NSString *destPath = [self createFullPath:[NSString stringWithFormat:@"%@/%@",destFolder.path,file.name]];

        get_context ctx;
        ctx.session = self.webDavSession;
        ctx.file = [destPath UTF8String];
        ctx.totalUploaded = &uploaded;
        
        int fd = open([file.fullPath UTF8String], O_RDONLY);
        struct stat st;
        fstat(fd, &st);
        char *uri = ne_path_escape([destPath UTF8String]);
        
        ne_request *req = ne_request_create(self.webDavSession, "PUT", uri);
        ne_set_notifier(self.webDavSession, status, &ctx);
        
        if (overwrite == NO)
        {
            ne_add_request_header(req, "If-None-Match", "*");
        }
        
        ne_lock_using_resource(req, uri, 0);
        ne_lock_using_parent(req, uri);
        
        ne_set_request_body_fd(req, fd, 0, st.st_size);
        
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                         0, 0, dispatch_get_main_queue());
        long long totalSize = [file.fileSizeNumber longLongValue];
        if (timer)
        {
            dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), 100 * USEC_PER_SEC,  100 * USEC_PER_SEC);
            dispatch_source_set_event_handler(timer, ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMUploadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithLongLong:*(ctx.totalUploaded)],@"uploadedBytes",
                                                     file.fileSizeNumber,@"totalBytes",
                                                     [NSNumber numberWithFloat:(float)((float)*(ctx.totalUploaded)/(float)totalSize)],@"progress",
                                                     nil]];
                });
            });
            dispatch_resume(timer);
        }
        
        ret = ne_request_dispatch(req);
        
        if ((ret == NE_OK && ne_get_status(req)->klass != 2) ||
            (ret != NE_OK))
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [[NSString alloc] initWithUTF8String:ne_get_error(self.webDavSession)],@"error",
                                                 nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:YES],@"success",
                                                 nil]];
            });
        }
        
        ne_set_notifier(self.webDavSession, NULL, NULL);
        ne_request_destroy(req);
        free(uri);
        close(fd);
        
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file
{
    NSMutableString *urlString = [NSMutableString stringWithString:[self createRootURLStringWithCredentials]];
    
    NSArray *pathArray = [[self createFullPath:file.path] componentsSeparatedByString:@"/"];
    
    NSInteger i;
    for (i = 0; i < [pathArray count]; i++)
    {
        [urlString appendFormat:@"/%@",[[pathArray objectAtIndex:i] encodeStringUrl:NSUTF8StringEncoding]];
    }
    
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.url = [NSURL URLWithString:urlString];
    networkConnection.urlType = URLTYPE_HTTP;
    networkConnection.requestCookies = [[NSMutableDictionary alloc] init];
    NSArray *all = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:networkConnection.url];
    for (NSHTTPCookie *cookie in all)
    {
        [networkConnection.requestCookies addEntriesFromDictionary:[NSDictionary dictionaryWithObject:cookie.value forKey:cookie.name]];
    }

    NSLog(@"%@",networkConnection.url);
    
  	return networkConnection;
}
#endif

/* Server features */
- (long long)supportedFeaturesAtPath:(NSString *)path
{
    long long features =  CMSupportedFeaturesMaskFileDelete      |
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
                          CMSupportedFeaturesMaskAirPlay         |
                          CMSupportedFeaturesMaskGoogleCast;
    if (trustedCert)
    {
        // For now I didn't find a way to use internal QT player to play
        // media on a server with untrusted certificate !
        features |= CMSupportedFeaturesMaskQTPlayer |
                    CMSupportedFeaturesMaskVLCPlayer;
    }
    return features;
}

#pragma mark - neon callback

static int ssl_verify_callback(void *userdata, int failures, const ne_ssl_certificate *cert)
{
    ssl_verify_context *ctx = (ssl_verify_context *)userdata;
    // We assume everything is OK
    *(ctx->trustedcertificate) = YES;

    char *issuer = ne_ssl_readable_dname(ne_ssl_cert_issuer(cert));
    char *subject = ne_ssl_readable_dname(ne_ssl_cert_subject(cert));
    char *digest = ne_calloc(NE_SSL_DIGESTLEN);
    if (!issuer || !subject || ne_ssl_cert_digest(cert, digest) != 0) {
        printf("error processing server certificate");
        if (issuer) free(issuer);
        if (subject) free(subject);
        if (digest) free(digest);
        return -1;
    }
    
    int ret = 0; // accept certificate
#warning use ne_set_error ?
    if (failures & NE_SSL_NOTYETVALID)
    {
        printf("the server certificate is not yet valid\n");
        ret = -1;
    }
    if (failures & NE_SSL_EXPIRED)
    {
        printf("the server certificate has expired\n");
        ret = -1;
    }
    if (failures & NE_SSL_IDMISMATCH)
    {
        printf("the server certificate does not match the server name\n");
    }
    if (failures & NE_SSL_UNTRUSTED)
    {
        printf("the server certificate is not trusted\n");
        *(ctx->trustedcertificate) = NO;
    }
    if (failures & ~NE_SSL_FAILMASK)
    {
        printf("unknown certificate error\n");
        ret = -1;
    }
    printf("  issuer: %s\n", issuer);
    printf("  subject: %s\n", subject);
    printf("  identity: %s\n",
           ne_ssl_cert_identity(cert));
    printf("  fingerprint: %s\n", digest);
    
    if (!ret)
    {
        printf("certificate accepted\n");
    }
    
    if (issuer) free(issuer);
    if (subject) free(subject);
    if (digest) free(digest);
    return ret;
}

static int auth_creds_callback(void* userdata, const char *realm, int attempts, char *username, char *password)
{
    auth_creds_context *ctx = (auth_creds_context *)userdata;
    strcpy(username, ctx->username);
    strcpy(password, ctx->password);
    return attempts;
}

static void
add_header(ne_request *req, void *userdata, ne_buffer *header)
{
    ne_buffer_zappend(header, (char *) userdata);
}

static int
update_cookie_callback(ne_request *req, void *userdata, const ne_status *status)
{
    if (status->klass != 2)
        return NE_OK;
    
    cookie_context *ctx = (cookie_context *)userdata;
    
    const char *cookie_hdr = ne_get_response_header(req, "Set-Cookie2");
    if (!cookie_hdr) {
        cookie_hdr = ne_get_response_header(req, "Set-Cookie");
    }
    if (!cookie_hdr)
        return NE_OK;
    
    if (cookie && strstr(cookie_hdr, cookie) == cookie_hdr)
        return NE_OK;
    
    char *sep = strpbrk(cookie_hdr, "\",; \n\r\0");
    if (!sep)
        return NE_OK;
    if (*sep == '\"')
        sep = strpbrk(sep + 1, "\"");
    if (!sep)
        return NE_OK;
    
    if (cookie) {
        ne_unhook_pre_send(ctx->session, add_header, cookie);
        free(cookie);
        cookie = NULL;
    }
    
    char *value = ne_strndup(cookie_hdr, sep - cookie_hdr + 1);
    cookie = ne_concat("Cookie: $Version=1;", value, "\r\n", NULL);
    
    // Store cookies in NSHTTPCookieStorage, this is needed to streamplay videos with internal player for example
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSString *urlString = [NSString stringWithFormat:@"%@://%@:%d",
                           [NSString stringWithUTF8String:ctx->scheme],
                           [NSString stringWithUTF8String:ctx->host],ctx->port];
    NSArray *cookiesArray = [[NSString stringWithUTF8String:value] componentsSeparatedByString:@";"];
    if ([cookiesArray count] > 1)
    {
        for (NSString *intermediateString in cookiesArray)
        {
            NSArray *cookieNameValue = [intermediateString componentsSeparatedByString:@"="];
            if ([cookieNameValue count] == 2)
            {
                NSHTTPCookie *httpCookie = [NSHTTPCookie cookieWithProperties:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                               [NSURL URLWithString:urlString],NSHTTPCookieOriginURL,
                                                                               [[NSURL URLWithString:urlString] path],NSHTTPCookiePath,
                                                                               [cookieNameValue objectAtIndex:0], NSHTTPCookieName,
                                                                               [cookieNameValue objectAtIndex:1], NSHTTPCookieValue,
                                                                               nil]];
                [storage setCookie:httpCookie];
            }
        }
    }
    
    free(value);
    
    ne_hook_pre_send(ctx->session, add_header, cookie);
    
    return NE_OK;
}

#pragma mark - file list parsing

static void dav_delete_props(dav_props *props)
{
    if (props->path)
    {
        free(props->path);
    }
    if (props->name)
    {
        free(props->name);
    }
    if (props->etag)
    {
        free(props->etag);
    }
    free(props);
}

/* Checks etag for weakness indicator and quotation marks.
 The return value is either a strong etag with quotation marks or NULL.
 Depending on global variable drop_weak_etags weak etags are either
 dropped or convertet into strong ones. */
static char *
normalize_etag(const char *etag)
{
    if (!etag) return NULL;
    
    const char * e = etag;
    if (*e == 'W')
    {
        e++;
        if (*e == '/') {
            e++;
        } else {
            return NULL;
        }
    }
    if (!*e) return NULL;
    
    char *ne = NULL;
    if (*e == '\"') {
        ne = strdup(e);
    } else {
        if (asprintf(&ne, "\"%s\"", e) < 0)
            ne = NULL;;
    }
    
    return ne;
}

static void
prop_result_callback(void *userdata, const ne_uri *uri, const ne_prop_result_set *set)
{
    propfind_context *ctx = (propfind_context *) userdata;
    if (!ctx || !uri || !uri->path || !set)
        return;
    
    char *tmp_path = (char *) ne_malloc(strlen(uri->path) + 1);
    const char *from = uri->path;
    
    char *to = tmp_path;
    while (*from) {
        while (*from == '/' && *(from + 1) == '/')
            from++;
        *to++ = *from++;
    }
    *to = 0;
    dav_props *result = ne_calloc(sizeof(dav_props));
    result->path = ne_path_unescape(tmp_path);
    free (tmp_path);
    
    // if the path (which includes filename) is empty or equal to "/", then the element is invalid
    if (!result->path || strlen(result->path) < 1 || (strcmp(result->path, "/") == 0)) {
        dav_delete_props(result);
        return;
    }
    
    const char *data;
    
    data = ne_propset_value(set, &prop_names[TYPE]);
    if (!data)
        data = ne_propset_value(set, &anonymous_prop_names[TYPE]);
    if (data && strstr(data, "collection"))
        result->is_dir = 1;
    
    // if the element is a folder, add '/' at the end of the path if needed
    // if the element is not a folder, remove the '/' at the end of the path if needed
    if (*(result->path + strlen(result->path) - 1) == '/') {
        if (!result->is_dir)
            *(result->path + strlen(result->path) - 1) = '\0';
    } else {
        if (result->is_dir) {
            char *tmp = ne_concat(result->path, "/", NULL);
            free(result->path);
            result->path = tmp;
        }
    }
    
    // If the folder of the element is different from the folder we are browsing, there is a problem, cancel parsing
    if (strstr(result->path, ctx->path) != result->path) {
        dav_delete_props(result);
        return;
    }
    
    if (strcmp(result->path, ctx->path) == 0) {
        // If path is equal to browsed folder, the name is empty
        result->name = ne_strdup("");
    } else {
        // If the path is
        if (strlen(result->path) < (strlen(ctx->path) + result->is_dir + 1)) {
            dav_delete_props(result);
            return;
        }
        result->name = ne_strndup(result->path + strlen(ctx->path),
                                  strlen(result->path) - strlen(ctx->path)
                                  - result->is_dir);
        NSLog(@"name %s\n",result->name);
    }
    
    data = ne_propset_value(set, &prop_names[ETAG]);
    if (!data)
        data = ne_propset_value(set, &anonymous_prop_names[ETAG]);
    result->etag = normalize_etag(data);
    
    data = ne_propset_value(set, &prop_names[LENGTH]);
    if (!data)
        data = ne_propset_value(set, &anonymous_prop_names[LENGTH]);
    if (data)
        result->size = strtoll(data, NULL, 10);
    
    data = ne_propset_value(set, &prop_names[CREATION]);
    if (!data)
        data = ne_propset_value(set, &anonymous_prop_names[CREATION]);
    if (data) {
        result->ctime = ne_iso8601_parse(data);
        if (result->ctime == (time_t) -1)
            result->ctime = ne_httpdate_parse(data);
        if (result->ctime == (time_t) -1)
            result->ctime = 0;
    }
    
    data = ne_propset_value(set, &prop_names[MODIFIED]);
    if (!data)
        data = ne_propset_value(set, &anonymous_prop_names[MODIFIED]);
    if (data) {
        result->mtime = ne_httpdate_parse(data);
        if (result->mtime == (time_t) -1)
            result->mtime = ne_iso8601_parse(data);
        if (result->mtime == (time_t) -1)
            result->mtime = 0;
    }
    
    data = ne_propset_value(set, &prop_names[EXECUTE]);
    if (!data)
        data = ne_propset_value(set, &anonymous_prop_names[EXECUTE]);
    if (!data) {
        result->is_exec = -1;
    } else if (*data == 'T') {
        result->is_exec = 1;
    }
    
    result->next = ctx->results;
    ctx->results = result;
}

@end
