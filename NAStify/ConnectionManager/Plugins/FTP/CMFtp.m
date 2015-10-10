//
//  CMFtp.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//
//  Documentation : http://cr.yp.to/ftp.html
//  Error codes : http://en.wikipedia.org/wiki/List_of_FTP_server_return_codes
//

#import "CMFtp.h"
#import "ftpparse.h"
#import "SBNetworkActivityIndicator.h"
#import "NSStringAdditions.h"
#import "SSKeychain.h"

#include <iconv.h>
#include <langinfo.h>

//#define CURLOPT_VERBOSE_LEVEL 1L
#define CURLOPT_VERBOSE_LEVEL 0L

#define FTP_CODE_ACTION_COMPLETED               200
#define FTP_CODE_FILE_ACTION_OK_DATA_CNX_CLOSED 226
#define FTP_CODE_FILE_ACTION_OK                 250
#define FTP_CODE_PATHNAME_CREATED               257
#define FTP_CODE_FILE_ACTION_PENDING            350

#define FTP_CODE_CNX_TIMEOUT                    421
#define FTP_CODE_CNX_DATA_ERROR                 425
#define FTP_CODE_CNX_CLOSED                     426
#define FTP_CODE_FILE_ACTION_NOT_TAKEN          450
#define FTP_CODE_INVALID_COMMAND                500
#define FTP_CODE_LOGIN_FAILED                   530
#define FTP_CODE_FILE_NOT_AVAILABLE             550
#define FTP_CODE_FILENAME_NOT_ALLOWED           553

id<CM> cself;
double lastNotifiedProgress;
BOOL abortDownload;
BOOL abortUpload;
static char error_buf[CURL_ERROR_SIZE];

@interface CMFtp (Private)
- (NSString *)createUrl;
- (BOOL)cString:(char *)cString
           size:(long)size
      forString:(NSString *)string
   fromEncoding:(NSString *)sourceEncoding
     toEncoding:(NSString *)destEncoding;
@end

@implementation CMFtp

- (id)init
{
    self = [super init];
    if (self)
    {
        backgroundQueue = dispatch_queue_create("com.sylver.nastify.local.bgqueue", NULL);
        curl = NULL;
        cself = self;
    }
    return self;
}

- (NSString *)createUrl
{
    NSString *url = self.userAccount.server;
    
    // Update URL for HTTP request if IPv6
    NSArray *components = [url componentsSeparatedByString:@":"];
    if ([components count] > 2)
    {
        // IPv6
        if ([[components objectAtIndex:0] isEqualToString:@"fe80"])
        {
            // Local adress, we have to add interface to use
            url = [NSString stringWithFormat:@"[%@%%25en0]",url];
        }
        else
        {
            url = [NSString stringWithFormat:@"[%@]",url];
        }
    }

    if (self.userAccount.serverType == SERVER_TYPE_SFTP)
    {
        return [NSString stringWithFormat:@"sftp://%@", url];
    }
    else
    {
        return [NSString stringWithFormat:@"ftp://%@", url];
    }
}

- (NSString *)createUrlWithCredentials
{
    NSString *url = self.userAccount.server;
    NSString *userName = self.userAccount.userName;
    NSString *password = [SSKeychain passwordForService:self.userAccount.uuid
                                                account:@"password"];
    if (!userName)
    {
        userName = @"anonymous";
        password = @"johndoe@mail.com";
    }

    
    // Update URL for HTTP request if IPv6
    NSArray *components = [url componentsSeparatedByString:@":"];
    if ([components count] > 2)
    {
        // IPv6
        if ([[components objectAtIndex:0] isEqualToString:@"fe80"])
        {
            // Local adress, we have to add interface to use
            url = [NSString stringWithFormat:@"[%@%%25en0]",url];
        }
        else
        {
            url = [NSString stringWithFormat:@"[%@]",url];
        }
    }

    if (self.userAccount.serverType == SERVER_TYPE_SFTP)
    {
        url = [NSString stringWithFormat:@"sftp://%@:%@@%@", userName, password, url];
    }
    else
    {
        url = [NSString stringWithFormat:@"ftp://%@:%@@%@", userName, password, url];
    }

    NSString *port = self.userAccount.port;
    if ((port == nil) || ([port length] == 0))
    {
        return url;
    }
    
    NSString * req = [NSString stringWithFormat:@"%@:%@", url, port];
    return req;
}

static void *myrealloc(void *ptr, size_t size)
{
    /* There might be a realloc() out there that doesn't like reallocing
     NULL pointers, so we take care of it here */
    if (ptr)
    {
        return realloc(ptr, size);
    }
    else
    {
        return malloc(size);
    }
}

static size_t WriteMemoryCallback(void *ptr, size_t size, size_t nmemb, void *data)
{
    size_t realsize = size * nmemb;
    struct CurlMemoryStruct *mem = (struct CurlMemoryStruct *)data;
    
    mem->memory = myrealloc(mem->memory, mem->size + realsize + 1);
    if (mem->memory) {
        memcpy(&(mem->memory[mem->size]), ptr, realsize);
        mem->size += realsize;
        mem->memory[mem->size] = 0;
    }
    return realsize;
}

- (void)defaultCurlOptions:(CURL *)_curl
{
    /* Switch on full protocol/debug output */
    curl_easy_setopt(_curl, CURLOPT_VERBOSE, CURLOPT_VERBOSE_LEVEL);
    curl_easy_setopt(_curl, CURLOPT_ERRORBUFFER, error_buf);
    
    curl_easy_setopt(_curl, CURLOPT_NOBODY, TRUE);
    
    // Setup url, login and password
    curl_easy_setopt(_curl, CURLOPT_URL,[[self createUrl] UTF8String]);
    curl_easy_setopt(_curl, CURLOPT_PORT, [self.userAccount.port intValue]);
    curl_easy_setopt(_curl, CURLOPT_USERNAME, [self.userAccount.userName UTF8String]);

    if (self.userAccount.transfertMode == TRANSFERT_MODE_FTP_ACTIVE)
    {
        // Set transfert mode to active (default is passive)
        curl_easy_setopt(_curl, CURLOPT_FTPPORT, "-");
    }
    
    if (self.userAccount.authenticationType == AUTHENTICATION_TYPE_PASSWORD)
    {
        NSString *password = [SSKeychain passwordForService:self.userAccount.uuid
                                                    account:@"password"];
        curl_easy_setopt(_curl, CURLOPT_PASSWORD, [password UTF8String]);
        curl_easy_setopt(_curl, CURLOPT_SSH_PUBLIC_KEYFILE,NULL);
        curl_easy_setopt(_curl, CURLOPT_SSH_PRIVATE_KEYFILE,NULL);
    }
    else // certificate
    {
        NSString *tmpDirectory = NSTemporaryDirectory();
        
        NSString *privateFile = [tmpDirectory stringByAppendingPathComponent:@"id_rsa"];
        NSString *pubFile = [tmpDirectory stringByAppendingPathComponent:@"id_rsa.pub"];
        
        NSString *publicCertificate = [SSKeychain passwordForService:self.userAccount.uuid
                                                             account:@"pubCert"];
        NSString *privateCertificate = [SSKeychain passwordForService:self.userAccount.uuid
                                                             account:@"privCert"];
        
        [publicCertificate writeToFile:pubFile
                            atomically:YES
                              encoding:NSUTF8StringEncoding
                                 error:nil];
        
        [privateCertificate writeToFile:privateFile
                             atomically:YES
                               encoding:NSUTF8StringEncoding
                                  error:nil];

        curl_easy_setopt(_curl, CURLOPT_SSH_PUBLIC_KEYFILE,[pubFile UTF8String]);
        curl_easy_setopt(_curl, CURLOPT_SSH_PRIVATE_KEYFILE,[privateFile UTF8String]);
    }
    
    curl_easy_setopt(_curl, CURLOPT_DIRLISTONLY, FALSE);
    curl_easy_setopt(_curl, CURLOPT_FTP_FILEMETHOD, CURLFTPMETHOD_NOCWD);
    curl_easy_setopt(_curl, CURLOPT_ENCODING, "UTF-8");

    if (self.userAccount.boolSSL)
    {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"ca-bundle" ofType:@"crt"];
        curl_easy_setopt(curl, CURLOPT_CAINFO, [path UTF8String]);

        // Enable FTPS (FTP with SSL)
        curl_easy_setopt(_curl, CURLOPT_FTP_SSL, CURLFTPSSL_ALL);
        curl_easy_setopt(_curl, CURLOPT_FTP_USE_EPSV, TRUE);
        curl_easy_setopt(_curl, CURLOPT_SSL_VERIFYPEER, FALSE);
        if (self.userAccount.acceptUntrustedCertificate)
        {
            curl_easy_setopt(_curl, CURLOPT_SSL_VERIFYHOST, 0L);
        }
        else
        {
            curl_easy_setopt(_curl, CURLOPT_SSL_VERIFYHOST, 2L);
        }
        curl_easy_setopt(_curl, CURLOPT_FTPSSLAUTH,CURLFTPAUTH_DEFAULT);
        curl_easy_setopt(_curl, CURLOPT_CERTINFO, TRUE);
    }
    else
    {
        curl_easy_setopt(_curl, CURLOPT_FTP_SSL, CURLFTPSSL_NONE);
    }
}

- (NSString *)stringForErrorCode:(long)code
{
    NSString *text = nil;
    switch (code) {
        case FTP_CODE_FILE_ACTION_NOT_TAKEN:
        {
            text = NSLocalizedString(@"Action not taken", nil);
            text = [text stringByAppendingFormat:@"\n%s",error_buf];
            break;
        }
        case FTP_CODE_FILE_NOT_AVAILABLE:
        {
            text = NSLocalizedString(@"File not available / Permission denied", nil);
            text = [text stringByAppendingFormat:@"\n%s",error_buf];
            break;
        }
        case FTP_CODE_CNX_DATA_ERROR:
        {
            text = NSLocalizedString(@"Can't open data connection", nil);
            text = [text stringByAppendingFormat:@"\n%s",error_buf];
            break;
        }
        case FTP_CODE_CNX_CLOSED:
        {
            text = NSLocalizedString(@"Connection closed, transfer aborted", nil);
            text = [text stringByAppendingFormat:@"\n%s",error_buf];
            break;
        }
        case FTP_CODE_INVALID_COMMAND:
        {
            text = NSLocalizedString(@"Invalid command sent to server", nil);
            text = [text stringByAppendingFormat:@"\n%s",error_buf];
            break;
        }
        case FTP_CODE_LOGIN_FAILED:
        {
            text = NSLocalizedString(@"Not logged in", nil);
            text = [text stringByAppendingFormat:@"\n%s",error_buf];
            break;
        }
        case FTP_CODE_CNX_TIMEOUT:
        {
            text = NSLocalizedString(@"Time out", nil);
            text = [text stringByAppendingFormat:@"\n%s",error_buf];
            break;
        }
        case FTP_CODE_FILENAME_NOT_ALLOWED:
        {
            text = NSLocalizedString(@"Filename not allowed / Permission denied", nil);
            text = [text stringByAppendingFormat:@"\n%s",error_buf];
            break;
        }
        default:
        {
            text = [NSString stringWithFormat:NSLocalizedString(@"Unknown error code (%ld)", nil),code];
            text = [text stringByAppendingFormat:@"\n%s",error_buf];
            break;
        }
    }
    return text;
}

- (NSString *)stringForCurlCode:(long)code
{
    NSString *text = nil;
    switch (code) {
        case CURLE_LOGIN_DENIED:
        {
            text = NSLocalizedString(@"Authentication failure", nil);
            break;
        }
        case CURLE_COULDNT_RESOLVE_HOST:
        {
            text = NSLocalizedString(@"Failed to resolve host", nil);
            break;
        }
        case CURLE_COULDNT_CONNECT:
        {
            text = NSLocalizedString(@"Failed to connect", nil);
            break;
        }
        case CURLE_REMOTE_ACCESS_DENIED:
        {
            text = NSLocalizedString(@"Access denied", nil);
            break;
        }
        case CURLE_REMOTE_FILE_NOT_FOUND:
        {
            text = NSLocalizedString(@"File not found", nil);
            break;
        }
        case CURLE_PEER_FAILED_VERIFICATION:
        {
            text = NSLocalizedString(@"SSL certificate problem", nil);
            break;
        }
        case CURLE_USE_SSL_FAILED:
        {
            text = NSLocalizedString(@"Requested FTP SSL level failed", nil);
            break;
        }
        case CURLE_QUOTE_ERROR:
        {
            text = NSLocalizedString(@"Command failed", nil);
            break;
        }
        case CURLE_SSL_CONNECT_ERROR:
        {
            text = NSLocalizedString(@"SSL/TLS handshake failed", nil);
            break;
        }
        case CURLE_RECV_ERROR:
        {
            text = NSLocalizedString(@"Receiving network data failed", nil);
            break;
        }
        default:
        {
            text = [NSString stringWithFormat:NSLocalizedString(@"Unknown curl code (%ld)", nil),code];
            break;
        }
    }
    return text;
}

#pragma mark - Server Info

- (NSArray *)serverInfo
{
    char *url;
    long *port;
    NSString *serverTypeString = nil;
    curl_easy_getinfo(curl, CURLINFO_EFFECTIVE_URL, &url);
    curl_easy_getinfo(curl, CURLINFO_PRIMARY_PORT, &port);

    if (self.userAccount.serverType == SERVER_TYPE_SFTP)
    {
        serverTypeString = NSLocalizedString(@"Server Type : SFTP",nil);
    }
    else if (self.userAccount.boolSSL)
    {
        serverTypeString = NSLocalizedString(@"Server Type : FTPS",nil);
    }
    else
    {
        serverTypeString = NSLocalizedString(@"Server Type : FTP",nil);
    }

    NSMutableArray *serverInfo = [NSMutableArray arrayWithObjects:
                                  serverTypeString,
                                  [NSString stringWithFormat:NSLocalizedString(@"Server URL : %s",nil),url],
                                  [NSString stringWithFormat:NSLocalizedString(@"Server port : %ld",nil),port],
                                  nil];
    
    if (self.userAccount.boolSSL)
    {
        struct curl_certinfo *info;
        
        curl_easy_getinfo(curl, CURLINFO_CERTINFO, &info);
        
        int i;
        
        printf("%d certs!\n", info->num_of_certs);
        
        for(i = 0; i < info->num_of_certs; i++) {
            struct curl_slist *slist;
            
            for(slist = info->certinfo[i]; slist; slist = slist->next)
            {
                [serverInfo addObject:[NSString stringWithFormat:@"%s",slist->data]];
            }
        }
    }
    if (self.userAccount.serverType == SERVER_TYPE_FTP)
    {
        [serverInfo addObject:[NSString stringWithFormat:NSLocalizedString(@"Server encoding : %@",nil),self.userAccount.encoding]];
    }
    
    curl_version_info_data *version;
    version = curl_version_info(CURLVERSION_NOW);
    
    [serverInfo addObject:[NSString stringWithFormat:NSLocalizedString(@"cURL %s, libz %s, %s",nil),version->version, version->libz_version, version->ssl_version]];
    return serverInfo;
}

#pragma mark - login/logout management

- (BOOL)login
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(backgroundQueue, ^(void) {
        CURLcode res;
        long ftpCode;
        
        curl_global_init(CURL_GLOBAL_DEFAULT);
        
        if (curl == nil)
        {
            curl = curl_easy_init();
        }
        
        [self defaultCurlOptions:curl];
        
        if (self.userAccount.serverType == SERVER_TYPE_SFTP)
        {
            // Start the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
            
            res = curl_easy_perform(curl);
            
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            if (res == CURLE_OK)
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
                                            [self stringForCurlCode:res],@"error",
                                            nil]];
                });
            }
        }
        else
        {
            curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "NOOP");
            
            // Start the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
            
            res = curl_easy_perform(curl);
            
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
            
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            if ((res == CURLE_OK) &&
                ((ftpCode == FTP_CODE_ACTION_COMPLETED) || (ftpCode == FTP_CODE_PATHNAME_CREATED)))
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:YES],@"success",
                                            nil]];
                });
            }
            else if (res == CURLE_OK)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [self stringForErrorCode:ftpCode],@"error",
                                            nil]];
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [self stringForCurlCode:res],@"error",
                                            nil]];
                });
            }
        }
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
    return YES;
}

-(BOOL) logout
{
    // Remove certificate files if needed
    if (self.userAccount.authenticationType == AUTHENTICATION_TYPE_CERTIFICATE)
    {
        NSString *tmpDirectory = NSTemporaryDirectory();
        
        NSString *privateFile = [tmpDirectory stringByAppendingPathComponent:@"id_rsa"];
        NSString *pubFile = [tmpDirectory stringByAppendingPathComponent:@"id_rsa.pub"];
        
        [[NSFileManager defaultManager] removeItemAtPath:privateFile
                                                   error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:pubFile
                                                   error:nil];
        
    }
    return FALSE;
}

#pragma mark - list files management

/* Return permission in POSIX format */
static int scan_perms (const char *s, int *perms)
{
    int p;
    int i;
    
    if ((*s != '-') && (*s != 'd') && (*s != 'l'))
        return 1;
    
    p = 0;
    
    for (i = 0; i < 9; ++i)
    {
        ++s;
        p <<= 1;
        if (*s == '-')
            continue;
        switch (i % 3)
        {
            case 0:
                if (*s != 'r')
                    return 0;
                break;
            case 1:
                if (*s != 'w')
                    return 0;
                break;
            case 2:
                if ((*s != 'x') && (*s != 's'))
                    return 0;
                break;
        }
        p |= 1;
    }
    
    *perms = p;
    return 1;
}

- (void)listForPath:(FileItem *)folder
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(backgroundQueue, ^(void) {
        CURLcode res = CURLE_OK;
        long ftpCode = 0;
        
        if (curl)
        {
            NSMutableArray *filesOutputArray = [NSMutableArray array];
            NSString *answerString = nil;
            struct CurlMemoryStruct response;
            response.memory = NULL;
            response.size = 0;
            
            curl_easy_setopt(curl, CURLOPT_NOBODY, FALSE);

            if (self.userAccount.serverType == SERVER_TYPE_SFTP)
            {
                // Request list
                NSString *url = [NSString stringWithFormat:@"%@%@/",[self createUrl],folder.path]; // URL shall ends with '/'
                curl_easy_setopt(curl, CURLOPT_URL,[url UTF8String]);
                
                curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
                curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&response);
                
                // Start the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

                res = curl_easy_perform(curl);
                
                curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, NULL);
                
                // End the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                
                curl_easy_setopt(curl, CURLOPT_URL,[[self createUrl] UTF8String]);

                if (res == CURLE_OK)
                {
                    NSData *data = [NSData dataWithBytes:(void *)response.memory length:response.size];
                    answerString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                }
                free(response.memory);
            }
            else // FTP
            {
                char encodedString[([folder.path length]) * 6 + 1 /* L'\0' */];
                if ([self cString:encodedString
                             size:sizeof(encodedString)
                        forString:folder.path
                     fromEncoding:@"UTF-8"
                       toEncoding:self.userAccount.encoding])
                {
                    // Build command
                    char cmd[sizeof(encodedString) + 10];
                    sprintf(cmd, "CWD %s",encodedString);

                    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, cmd);
                    
                    // Start the network activity spinner
                    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                    
                    res = curl_easy_perform(curl);
                    
                    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                    
                    // End the network activity spinner
                    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                    
                    if (((res == CURLE_OK) || (res == CURLE_FTP_COULDNT_RETR_FILE)) && // result is CURLE_FTP_COULDNT_RETR_FILE but everything is OK so continue
                        ((ftpCode == FTP_CODE_ACTION_COMPLETED) || (ftpCode == FTP_CODE_FILE_ACTION_OK)))
                    {
                        // Request list
                        curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "LIST -a");
                        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteMemoryCallback);
                        curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void *)&response);
                        
                        // Start the network activity spinner
                        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                        
                        res = curl_easy_perform(curl);
                        
                        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                        
                        // End the network activity spinner
                        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                        
                        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, NULL);
                        
                        if ((res == CURLE_OK) &&
                            ((ftpCode == FTP_CODE_FILE_ACTION_OK_DATA_CNX_CLOSED) || (ftpCode == 0)))
                        {
                            NSData *data = nil;

                            /* Convert response to UTF-8 */
                            signed char utf8[(response.size + 1 /* L'\0' */) * 6];
                            char *iconv_in = (char *) response.memory;
                            char *iconv_out = (char *) &utf8[0];
                            size_t iconv_in_bytes = response.size;
                            size_t iconv_out_bytes = sizeof(utf8);
                            size_t ret;
                            iconv_t cd;
                            
                            cd = iconv_open("UTF-8",[self.userAccount.encoding cStringUsingEncoding:NSUTF8StringEncoding]);
                            if ((iconv_t) -1 == cd) {
                                perror("iconv_open");
                            }
                            
                            ret = iconv(cd, &iconv_in, &iconv_in_bytes, &iconv_out, &iconv_out_bytes);
                            if ((size_t) -1 == ret) {
                                perror("iconv");
                            }
                            iconv_close(cd);
                            
                            data = [NSData dataWithBytes:(void *)utf8 length:sizeof(utf8)-iconv_out_bytes];

                            answerString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        }
                        free(response.memory);
                    }
                    else
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        [NSNumber numberWithBool:NO],@"success",
                                                        folder.path,@"path",
                                                        [self stringForErrorCode:ftpCode],@"error",
                                                        nil]];
                        });
                    }
                }
            }
            curl_easy_setopt(curl, CURLOPT_NOBODY, TRUE);
            
            if (answerString)
            {
                NSArray *lines = [answerString componentsSeparatedByString:@"\n"];
                for (NSString *string in lines)
                {
                    if ([string isEqualToString:@""])
                    {
                        break;
                    }
                    
                    int result = 0;
                    int permissions;
                    struct ftpparse element;
                    
                    result = ftpparse(&element,(char *)[string UTF8String],(int)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
                    
                    result = scan_perms((char *)[string UTF8String], &permissions);
                    NSNumber *permissionNumber = [NSNumber numberWithInt:permissions];
                    
                    NSString *fileName = [[NSString alloc] initWithBytes:element.name
                                                                  length:element.namelen
                                                                encoding:NSUTF8StringEncoding];
                    if ((![fileName isEqualToString:@"."]) &&
                        (![fileName isEqualToString:@".."]))
                    {
                        NSString *type = @"";
                        if ([[fileName componentsSeparatedByString:@"."] count] > 1)
                        {
                            type = [[fileName componentsSeparatedByString:@"."] lastObject];
                        }
                        
                        NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:element.flagtrycwd],@"isdir",
                                                  fileName,@"filename",
                                                  [NSNumber numberWithLongLong:element.size],@"filesizenumber",
                                                  [NSNumber numberWithBool:[permissionNumber userHasWriteAccessFromPosixPermissions]],@"writeaccess",
                                                  [NSString stringWithFormat:@"%ld",element.mtime],@"date",
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
            }
            else
            {
                if (self.userAccount.serverType == SERVER_TYPE_SFTP)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                    [NSNumber numberWithBool:NO],@"success",
                                                    folder.path,@"path",
                                                    [self stringForCurlCode:res],@"error",
                                                    nil]];
                    });
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                    [NSNumber numberWithBool:NO],@"success",
                                                    folder.path,@"path",
                                                    [self stringForErrorCode:ftpCode],@"error",
                                                    nil]];
                    });
                }
            }
        }
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

#pragma mark - Folder creation management

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(backgroundQueue, ^(void) {
        struct curl_slist* header = NULL;
        CURLcode res;
        long ftpCode;
        
        if (self.userAccount.serverType == SERVER_TYPE_SFTP)
        {
                // Build command
                NSString *cmd = [NSString stringWithFormat:@"mkdir \"%@/%@\"",[folder.path stringWithSlash],[folderName stringWithSlash]];
                header = curl_slist_append(header, [cmd UTF8String]);
                
                curl_easy_setopt(curl, CURLOPT_POSTQUOTE, header);
            
                // Start the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                
                CURLcode res = curl_easy_perform(curl);
                
                curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                
                // End the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                
                curl_easy_setopt(curl, CURLOPT_POSTQUOTE, NULL);
            
                curl_slist_free_all(header);
                
                if (res == CURLE_OK)
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
                                                       [self stringForCurlCode:res],@"error",
                                                       nil]];
                    });
                }
        }
        else
        {
            char encodedPath[([folder.path length]) * 6 + 1 /* L'\0' */];
            if ([self cString:encodedPath
                         size:sizeof(encodedPath)
                    forString:folder.path
                 fromEncoding:@"UTF-8"
                   toEncoding:self.userAccount.encoding])
            {
                // Build command
                char cmd[sizeof(encodedPath) + 10];
                sprintf(cmd, "CWD %s",encodedPath);
                
                curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, cmd);
                curl_easy_setopt(curl, CURLOPT_NOBODY, FALSE);

                // Start the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                
                res = curl_easy_perform(curl);
                
                curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                
                // End the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                
                curl_easy_setopt(curl, CURLOPT_NOBODY, TRUE);
                
                if (((res == CURLE_OK) || (res == CURLE_FTP_COULDNT_RETR_FILE)) && // result is CURLE_FTP_COULDNT_RETR_FILE but everything is OK so continue
                    ((ftpCode == FTP_CODE_ACTION_COMPLETED) || (ftpCode == FTP_CODE_FILE_ACTION_OK)))
                {
                    char encodedString[([folderName length]) * 6 + 1 /* L'\0' */];
                    if ([self cString:encodedString
                                 size:sizeof(encodedString)
                            forString:folderName
                         fromEncoding:@"UTF-8"
                           toEncoding:self.userAccount.encoding])
                    {
                        // Build command
                        char cmd[sizeof(encodedString) + 10];
                        
                        sprintf(cmd, "MKD %s",encodedString);
                        
                        header = curl_slist_append(header, cmd);
                        
                        curl_easy_setopt(curl, CURLOPT_POSTQUOTE, header);
                        
                        // Start the network activity spinner
                        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                        
                        res = curl_easy_perform(curl);
                        
                        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                        
                        // End the network activity spinner
                        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                        
                        curl_easy_setopt(curl, CURLOPT_POSTQUOTE, NULL);
                        
                        curl_slist_free_all(header);
                        
                        if ((res == CURLE_OK) &&
                            ((ftpCode == FTP_CODE_FILE_ACTION_OK) || (ftpCode == FTP_CODE_PATHNAME_CREATED)))
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
                                                               [self stringForErrorCode:ftpCode],@"error",
                                                               nil]];
                            });
                        }
                    }
                    else
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:NO],@"success",
                                                           @"Character coding error",@"error",
                                                           nil]];
                        });
                    }
                }
                else
                {
                    // CWD command failed
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       [self stringForErrorCode:ftpCode],@"error",
                                                       nil]];
                    });
                }
            }
        }
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

#pragma mark - Delete management

#ifndef APP_EXTENSION
- (void)deleteFile:(FileItem *)file
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void) {
        struct curl_slist* header = NULL;
        
        if (self.userAccount.serverType == SERVER_TYPE_SFTP)
        {
            // Build command
            NSString *cmd = nil;
            if (file.isDir)
            {
                cmd = [NSString stringWithFormat:@"rmdir \"%@/\"",[file.path stringWithSlash]];
            }
            else
            {
                cmd = [NSString stringWithFormat:@"rm \"%@\"",[file.path stringWithSlash]];
            }
            
            header = curl_slist_append(header, [cmd UTF8String]);
            
            curl_easy_setopt(curl, CURLOPT_POSTQUOTE, header);
            
            // Start the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
            
            CURLcode res = curl_easy_perform(curl);
            
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            curl_easy_setopt(curl, CURLOPT_POSTQUOTE, NULL);
            
            curl_slist_free_all(header);
            
            if ((res == CURLE_OK) &&
                (self.cancelDelete == FALSE))
            {
                [self.filesToDelete removeObjectAtIndex:0];
                if ([self.filesToDelete count] > 0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        float progress = (float)((float)(self.filesToDeleteCount-[self.filesToDelete count])/(float)self.filesToDeleteCount);
                        [self.delegate CMDeleteProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithFloat:progress],@"progress",
                                                         nil]];
                    });
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self deleteFile:[self.filesToDelete objectAtIndex:0]];
                    });
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:YES],@"success",
                                                         nil]];
                    });
                    self.filesToDelete = nil;
                    self.filesToDeleteCount = 0;
                }
            }
            else if (self.cancelDelete == FALSE)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     [self stringForCurlCode:res],@"error",
                                                     nil]];
                });
                self.filesToDelete = nil;
                self.filesToDeleteCount = 0;
            }
        }
        else
        {
            long ftpCode;
            
            char encodedString[([file.path length]) * 6 + 1 /* L'\0' */];
            if ([self cString:encodedString
                         size:sizeof(encodedString)
                    forString:file.path
                 fromEncoding:@"UTF-8"
                   toEncoding:self.userAccount.encoding])
            {
                // Build command
                char cmd[sizeof(encodedString) + 10];
                
                if (file.isDir)
                {
                    sprintf(cmd, "RMD %s",encodedString);
                }
                else
                {
                    sprintf(cmd, "DELE %s",encodedString);
                }
                
                header = curl_slist_append(header, cmd);
                
                curl_easy_setopt(curl, CURLOPT_POSTQUOTE, header);
                
                // Start the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                
                CURLcode res = curl_easy_perform(curl);
                
                curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                
                // End the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                
                curl_easy_setopt(curl, CURLOPT_POSTQUOTE, NULL);
                
                curl_slist_free_all(header);
                
                if ((res == CURLE_OK) &&
                    (ftpCode == FTP_CODE_FILE_ACTION_OK) &&
                    (self.cancelDelete == FALSE))
                {
                    [self.filesToDelete removeObjectAtIndex:0];
                    if ([self.filesToDelete count] > 0)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            float progress = (float)((float)(self.filesToDeleteCount-[self.filesToDelete count])/(float)self.filesToDeleteCount);
                            [self.delegate CMDeleteProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithFloat:progress],@"progress",
                                                             nil]];
                        });
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self deleteFile:[self.filesToDelete objectAtIndex:0]];
                        });
                    }
                    else
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithBool:YES],@"success",
                                                             nil]];
                        });
                        self.filesToDelete = nil;
                        self.filesToDeleteCount = 0;
                    }
                }
                else if (self.cancelDelete == FALSE)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         [self stringForErrorCode:ftpCode],@"error",
                                                         nil]];
                    });
                    self.filesToDelete = nil;
                    self.filesToDeleteCount = 0;
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     @"Character coding error",@"error",
                                                     nil]];
                });
            }
        }
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}

- (void)deleteFiles:(NSArray *)files
{
    // FTP can only handle files one by one
    self.filesToDelete = [NSMutableArray arrayWithArray:files];
    self.filesToDeleteCount = [files count];
    self.cancelDelete = NO;
    [self deleteFile:[self.filesToDelete objectAtIndex:0]];
}

- (void)cancelDeleteTask
{
    self.cancelDelete = YES;
}
#endif

#pragma mark - Move management

#ifndef APP_EXTENSION
- (void)moveFile:(FileItem *)file toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void) {
        struct curl_slist* header = NULL;
        
        if (self.userAccount.serverType == SERVER_TYPE_SFTP)
        {
            // Build command
            NSString *cmd = [NSString stringWithFormat:@"rename \"%@\" \"%@/%@\"",
                             [file.path stringWithSlash],
                             [destFolder.path stringWithSlash],
                             [file.name stringWithSlash]];
            
            header = curl_slist_append(header, [cmd UTF8String]);
            
            curl_easy_setopt(curl, CURLOPT_POSTQUOTE, header);
            
            // Start the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
            
            CURLcode res = curl_easy_perform(curl);
            
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            curl_easy_setopt(curl, CURLOPT_POSTQUOTE, NULL);
            
            curl_slist_free_all(header);
            header = NULL;
            
            if (res == CURLE_OK)
            {
                if (res == CURLE_OK)
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
                                                       [self stringForCurlCode:res],@"error",
                                                       nil]];
                    });
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [self stringForCurlCode:res],@"error",
                                                   nil]];
                });
            }
        }
        else
        {
            long ftpCode;
            
            NSString *newName = [NSString stringWithFormat:@"%@/%@", destFolder.path, file.name];
            char encodedOldName[([file.path length]) * 6 + 1 /* L'\0' */];
            char encodedNewName[([newName length]) * 6 + 1 /* L'\0' */];
            
            if (([self cString:encodedOldName
                          size:sizeof(encodedOldName)
                     forString:file.path
                  fromEncoding:@"UTF-8"
                    toEncoding:self.userAccount.encoding]) &&
                ([self cString:encodedNewName
                          size:sizeof(encodedNewName)
                     forString:newName
                  fromEncoding:@"UTF-8"
                    toEncoding:self.userAccount.encoding]))
            {
                // Build command
                char cmd[sizeof(encodedOldName) + 10];
                
                sprintf(cmd, "RNFR %s",encodedOldName);
                
                header = curl_slist_append(header, cmd);
                
                curl_easy_setopt(curl, CURLOPT_POSTQUOTE, header);
                
                // Start the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                
                CURLcode res = curl_easy_perform(curl);
                
                curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                
                curl_easy_setopt(curl, CURLOPT_POSTQUOTE, NULL);
                
                curl_slist_free_all(header);
                header = NULL;
                
                if ((res == CURLE_OK) && (ftpCode == FTP_CODE_FILE_ACTION_PENDING))
                {
                    // Send new name
                    char cmd2[sizeof(encodedNewName) + 10];
                    
                    sprintf(cmd2, "RNTO %s",encodedNewName);
                    printf("%s",cmd2);
                    header = curl_slist_append(header, cmd2);
                    
                    curl_easy_setopt(curl, CURLOPT_POSTQUOTE, header);
                    
                    // Start the network activity spinner
                    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                    
                    res = curl_easy_perform(curl);
                    
                    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                    
                    // End the network activity spinner
                    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                    
                    curl_easy_setopt(curl, CURLOPT_POSTQUOTE, NULL);
                    
                    curl_slist_free_all(header);
                    
                    if ((res == CURLE_OK) &&
                        (ftpCode == FTP_CODE_FILE_ACTION_OK) &&
                        (self.cancelMove == FALSE))
                        
                    {
                        [self.filesToMove removeObjectAtIndex:0];
                        if ([self.filesToMove count] > 0)
                        {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                float progress = (float)((float)(self.filesToMoveCount-[self.filesToMove count])/(float)self.filesToMoveCount);
                                [self.delegate CMMoveProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                               [NSNumber numberWithFloat:progress],@"progress",
                                                               nil]];
                            });
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self moveFile:[self.filesToMove objectAtIndex:0]
                                        toPath:destFolder
                                  andOverwrite:overwrite];
                            });
                        }
                        else
                        {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                               [NSNumber numberWithBool:YES],@"success",
                                                               nil]];
                            });
                            self.filesToMove = nil;
                            self.filesToMoveCount = 0;
                        }
                    }
                    else if (self.cancelMove == FALSE)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:NO],@"success",
                                                           [self stringForErrorCode:ftpCode],@"error",
                                                           nil]];
                        });
                        self.filesToMove = nil;
                        self.filesToMoveCount = 0;
                    }
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       [self stringForErrorCode:ftpCode],@"error",
                                                       nil]];
                    });
                    self.filesToMove = nil;
                    self.filesToMoveCount = 0;
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   @"Character coding error",@"error",
                                                   nil]];
                });
                self.filesToMove = nil;
                self.filesToMoveCount = 0;
            }
        }
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}

- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    self.filesToMove = [NSMutableArray arrayWithArray:files];
    self.filesToMoveCount = [files count];
    self.cancelMove = NO;
    [self moveFile:[self.filesToMove objectAtIndex:0] toPath:destFolder andOverwrite:overwrite];
}

- (void)cancelMoveTask
{
    self.cancelMove = YES;
}
#endif

#pragma mark - Rename management

#ifndef APP_EXTENSION
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(backgroundQueue, ^(void) {
        struct curl_slist* header = NULL;
        if (self.userAccount.serverType == SERVER_TYPE_SFTP)
        {
            // Build command
            NSString *cmd = [NSString stringWithFormat:@"rename \"%@/%@\" \"%@/%@\"",[folder.path stringWithSlash],[oldFile.name stringWithSlash],[folder.path stringWithSlash],[newName stringWithSlash]];

            header = curl_slist_append(header, [cmd UTF8String]);
            
            curl_easy_setopt(curl, CURLOPT_POSTQUOTE, header);
            
            // Start the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
            
            CURLcode res = curl_easy_perform(curl);
            
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

            curl_easy_setopt(curl, CURLOPT_POSTQUOTE, NULL);
            
            curl_slist_free_all(header);
            header = NULL;
            
            if (res == CURLE_OK)
            {
                if (res == CURLE_OK)
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
                                                 [self stringForCurlCode:res],@"error",
                                                 nil]];
                    });
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             [self stringForCurlCode:res],@"error",
                                             nil]];
                });
            }
        }
        else
        {
            long ftpCode;
            NSString *oldPath = [NSString stringWithFormat:@"%@/%@",folder.path,oldFile.name];
            NSString *newPath = [NSString stringWithFormat:@"%@/%@",folder.path,newName];
            char encodedOldName[([oldPath length]) * 6 + 1 /* L'\0' */];
            char encodedNewName[([newPath length]) * 6 + 1 /* L'\0' */];
            
            if (([self cString:encodedOldName
                          size:sizeof(encodedOldName)
                     forString:oldPath
                  fromEncoding:@"UTF-8"
                    toEncoding:self.userAccount.encoding]) &&
                ([self cString:encodedNewName
                          size:sizeof(encodedNewName)
                     forString:newPath
                  fromEncoding:@"UTF-8"
                    toEncoding:self.userAccount.encoding]))
            {
                // Send name of file to rename
                char cmd[sizeof(encodedOldName) + 10];
                
                sprintf(cmd, "RNFR %s",encodedOldName);
                
                header = curl_slist_append(header, cmd);
                
                curl_easy_setopt(curl, CURLOPT_POSTQUOTE, header);
                
                // Start the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                
                CURLcode res = curl_easy_perform(curl);
                
                curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                
                // End the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

                curl_easy_setopt(curl, CURLOPT_POSTQUOTE, NULL);

                curl_slist_free_all(header);
                header = NULL;
                
                if ((res == CURLE_OK) && (ftpCode == FTP_CODE_FILE_ACTION_PENDING))
                {
                    // Send new name
                    char cmd2[sizeof(encodedNewName) + 10];
                    
                    sprintf(cmd2, "RNTO %s",encodedNewName);
                    
                    header = curl_slist_append(header, cmd2);
                    
                    curl_easy_setopt(curl, CURLOPT_POSTQUOTE, header);
                    
                    // Start the network activity spinner
                    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

                    res = curl_easy_perform(curl);
                    
                    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                    
                    // End the network activity spinner
                    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                    
                    curl_easy_setopt(curl, CURLOPT_POSTQUOTE, NULL);
                    
                    curl_slist_free_all(header);
                    
                    if ((res == CURLE_OK) && (ftpCode == FTP_CODE_FILE_ACTION_OK))
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
                                                     [self stringForErrorCode:ftpCode],@"error",
                                                     nil]];
                        });
                    }
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [self stringForErrorCode:ftpCode],@"error",
                                                 nil]];
                    });
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             @"Character coding error",@"error",
                                             nil]];
                });
            }
        }
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}
#endif

#pragma mark - Download management
static size_t write_data (void *ptr, size_t size, size_t nmemb, FILE *stream)
{
    return fwrite(ptr, size, nmemb, stream);
}

static int download_progress (void *p, double dltotal, double dlnow, double ultotal, double ulnow)
{
    if (abortDownload)
    {
        return 1;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ((dlnow >= lastNotifiedProgress + dltotal/800) || (dlnow == dltotal))
        {
            lastNotifiedProgress = dlnow;

            [cself.delegate CMDownloadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithDouble:dlnow],@"downloadedBytes",
                                                [NSNumber numberWithDouble:dltotal],@"totalBytes",
                                                [NSNumber numberWithDouble:dlnow/dltotal],@"progress",
                                                nil]];
        }
    });
    
    return 0;
}

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(backgroundQueue, ^(void) {
        FILE *fp;
        long ftpCode;
        
        abortDownload = FALSE;
        
        /* file handle for writing */
        fp=fopen([localName UTF8String],"wb");
        
        if (self.userAccount.serverType == SERVER_TYPE_SFTP)
        {
            // Build command
            NSString *url = [NSString stringWithFormat:@"%@%@",[self createUrl],[file.path encodePathString:NSUTF8StringEncoding]];
            curl_easy_setopt(curl, CURLOPT_URL,[url UTF8String]);
            curl_easy_setopt(curl, CURLOPT_NOBODY, FALSE);
            
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
            
            curl_easy_setopt(curl, CURLOPT_PROGRESSFUNCTION, download_progress);
            curl_easy_setopt(curl, CURLOPT_NOPROGRESS, FALSE);
            curl_easy_setopt(curl, CURLOPT_FTP_FILEMETHOD, CURLFTPMETHOD_DEFAULT);
            
            // Start the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
            
            CURLcode res = curl_easy_perform(curl);
            
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            if (res == CURLE_OK)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:YES],@"success",
                                                       nil]];
                });
            }
            else if (abortDownload == NO)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       [self stringForCurlCode:res],@"error",
                                                       nil]];
                });
            }
            curl_easy_setopt(curl, CURLOPT_URL,[[self createUrl] UTF8String]);
            curl_easy_setopt(curl, CURLOPT_NOBODY, TRUE);
        }
        else
        {
            char encodedString[([file.path length]) * 6 + 1 /* L'\0' */];
            if ([self cString:encodedString
                         size:sizeof(encodedString)
                    forString:file.path
                 fromEncoding:@"UTF-8"
                   toEncoding:self.userAccount.encoding])
            {
                // Build command
                char url[[[self createUrl] length] + sizeof(encodedString) + 10];
                
                sprintf(url, "%s%s",[[self createUrl] UTF8String],encodedString);
                
                curl_easy_setopt(curl, CURLOPT_URL,url);
                curl_easy_setopt(curl, CURLOPT_NOBODY, FALSE);
                
                curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_data);
                curl_easy_setopt(curl, CURLOPT_WRITEDATA, fp);
                //curl_easy_setopt(curl, CURLOPT_FTP_USE_EPSV, FALSE);
                
                curl_easy_setopt(curl, CURLOPT_PROGRESSFUNCTION, download_progress);
                //curl_easy_setopt(curl, CURLOPT_PROGRESSDATA, &dlspeed);
                curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0L);
                curl_easy_setopt(curl, CURLOPT_FTP_FILEMETHOD, CURLFTPMETHOD_DEFAULT);
                
                // Start the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                
                CURLcode res = curl_easy_perform(curl);
                
                curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                
                // End the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                
                if ((res == CURLE_OK) && (ftpCode == FTP_CODE_FILE_ACTION_OK_DATA_CNX_CLOSED))
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:YES],@"success",
                                                           nil]];
                    });
                }
                else if (abortDownload == NO)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:NO],@"success",
                                                           [self stringForErrorCode:ftpCode],@"error",
                                                           nil]];
                    });
                }
                
                curl_easy_setopt(curl, CURLOPT_URL,[[self createUrl] UTF8String]);
                curl_easy_setopt(curl, CURLOPT_NOBODY, TRUE);
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       @"Character coding error",@"error",
                                                       nil]];
                });
            }
        }
        
        fclose(fp);
        
        if (abortDownload)
        {
            // delete partially downloaded file
            [[NSFileManager defaultManager] removeItemAtPath:localName
                                                       error:nil];
        }
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

- (void)cancelDownloadTask
{
    // Cancel request
    abortDownload = YES;
}

#pragma mark - Upload management

struct uploadctx {
    FILE *fp;
    double transfered;
    double size;
};

static size_t read_callback(void *ptr, size_t size, size_t nmemb, void *p)
{
    if (abortUpload)
    {
        return 0;
    }
    struct uploadctx *ulCtx = (struct uploadctx *)p;
    size_t retcode = fread(ptr, size, nmemb, ulCtx->fp);

    ulCtx->transfered += retcode;
    
    if ((ulCtx->transfered >= lastNotifiedProgress + ulCtx->size/800) || (ulCtx->transfered == ulCtx->size))
    {
        lastNotifiedProgress = ulCtx->transfered;
        
        [cself.delegate CMUploadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithDouble:ulCtx->transfered],@"uploadedBytes",
                                          [NSNumber numberWithDouble:ulCtx->size],@"totalBytes",
                                          [NSNumber numberWithDouble:(float)ulCtx->transfered/(float)ulCtx->size],@"progress",
                                          nil]];
    }
    return retcode;
}

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(backgroundQueue, ^(void) {
        long ftpCode;
        struct uploadctx ulCtx;
        NSString *filePath = file.fullPath;
        
        abortUpload = NO;
        
        ulCtx.fp = fopen([filePath UTF8String],"r");
        ulCtx.transfered = 0;
        if (ulCtx.fp != NULL)
        {
            
            fseek(ulCtx.fp, 0L, SEEK_END);
            ulCtx.size = ftell(ulCtx.fp);
            fseek(ulCtx.fp, 0L, SEEK_SET);
            
            if (self.userAccount.serverType == SERVER_TYPE_SFTP)
            {
                // Build command
                NSString *url = [NSString stringWithFormat:@"%@%@/%@",[self createUrl],[destFolder.path encodePathString:NSUTF8StringEncoding],[file.name encodePathString:NSUTF8StringEncoding]];
                
                curl_easy_setopt(curl, CURLOPT_URL,[url UTF8String]);
                curl_easy_setopt(curl, CURLOPT_NOBODY, FALSE);
                
                curl_easy_setopt(curl, CURLOPT_UPLOAD, TRUE);
                curl_easy_setopt(curl, CURLOPT_READFUNCTION, read_callback);
                curl_easy_setopt(curl, CURLOPT_READDATA, &ulCtx);
                
                // Start the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                
                CURLcode res = curl_easy_perform(curl);
                
                // End the network activity spinner
                [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                
                if (res == CURLE_OK)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:YES],@"success",
                                                         nil]];
                    });
                }
                else if (abortUpload == NO)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         [self stringForCurlCode:res],@"error",
                                                         nil]];
                    });
                }
                curl_easy_setopt(curl, CURLOPT_URL,[[self createUrl] UTF8String]);
                curl_easy_setopt(curl, CURLOPT_NOBODY, TRUE);
                curl_easy_setopt(curl, CURLOPT_UPLOAD, FALSE);
                curl_easy_setopt(curl, CURLOPT_READFUNCTION, NULL);
            }
            else
            {
                CURLcode res;
                char encodedPath[([destFolder.path length]) * 6 + 1 /* L'\0' */];
                if ([self cString:encodedPath
                             size:sizeof(encodedPath)
                        forString:destFolder.path
                     fromEncoding:@"UTF-8"
                       toEncoding:self.userAccount.encoding])
                {
                    // Build command
                    char cmd[sizeof(encodedPath) + 10];
                    sprintf(cmd, "CWD %s",encodedPath);
                    
                    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, cmd);
                    curl_easy_setopt(curl, CURLOPT_NOBODY, FALSE);
                    
                    // Start the network activity spinner
                    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                    
                    res = curl_easy_perform(curl);
                    
                    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                    
                    // End the network activity spinner
                    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                    
                    curl_easy_setopt(curl, CURLOPT_NOBODY, TRUE);
                    
                    if (((res == CURLE_OK) || (res == CURLE_FTP_COULDNT_RETR_FILE)) && // result is CURLE_FTP_COULDNT_RETR_FILE but everything is OK so continue
                        ((ftpCode == FTP_CODE_ACTION_COMPLETED) || (ftpCode == FTP_CODE_FILE_ACTION_OK)))
                    {
                        char encodedString[([file.name length]) * 6 + 1 /* L'\0' */];
                        if ([self cString:encodedString
                                     size:sizeof(encodedString)
                                forString:file.name
                             fromEncoding:@"UTF-8"
                               toEncoding:self.userAccount.encoding])
                        {
                            // Build command
                            char url[[[self createUrl] length] + sizeof(encodedString) + 10];
                            
                            sprintf(url, "%s/%s",[[self createUrl] UTF8String],encodedString);
                            curl_easy_setopt(curl, CURLOPT_URL,url);
                            
                            curl_easy_setopt(curl, CURLOPT_NOBODY, FALSE);
                            
                            curl_easy_setopt(curl, CURLOPT_UPLOAD, TRUE);
                            curl_easy_setopt(curl, CURLOPT_READFUNCTION, read_callback);
                            curl_easy_setopt(curl, CURLOPT_READDATA, &ulCtx);
                            
                            // Start the network activity spinner
                            [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
                            
                            curl_easy_perform(curl);
                            
                            // End the network activity spinner
                            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                            
                            res = curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &ftpCode);
                            
                            if ((res == CURLE_OK) && (ftpCode == FTP_CODE_FILE_ACTION_OK_DATA_CNX_CLOSED))
                            {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                     [NSNumber numberWithBool:YES],@"success",
                                                                     nil]];
                                });
                            }
                            else if (abortUpload == NO)
                            {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                     [NSNumber numberWithBool:NO],@"success",
                                                                     [self stringForErrorCode:ftpCode],@"error",
                                                                     nil]];
                                });
                            }
                            
                            curl_easy_setopt(curl, CURLOPT_URL,[[self createUrl] UTF8String]);
                            curl_easy_setopt(curl, CURLOPT_NOBODY, TRUE);
                            curl_easy_setopt(curl, CURLOPT_UPLOAD, FALSE);
                            curl_easy_setopt(curl, CURLOPT_READFUNCTION, NULL);
                        }
                        else
                        {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [NSNumber numberWithBool:NO],@"success",
                                                                 @"Character encoding error",@"error",
                                                                 nil]];
                            });
                        }
                    }
                    else
                    {
                        // CWD failed
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithBool:NO],@"success",
                                                             [self stringForErrorCode:ftpCode],@"error",
                                                             nil]];
                        });
                    }
                }
                else
                {
                    // Path encoding failed
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         @"Character encoding error",@"error",
                                                         nil]];
                    });
                }
            }
            fclose(ulCtx.fp);
        }
        else
        {
            // File access error
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 @"Unable to access file",@"error",
                                                 nil]];
            });
        }
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

- (void)cancelUploadTask
{
    // Cancel request
    abortUpload = YES;
}

#pragma mark - url management

#ifndef APP_EXTENSION
- (NetworkConnection *)urlForVideo:(FileItem *)file
{
    NSArray *pathArray = [file.shortPath componentsSeparatedByString:@"/"];
    NSMutableString *urlString = nil;
    
    // when using an anonymous login, don't include credentials in the url or libVLC will not play the file
    if ((!self.userAccount.userName) ||
        ([self.userAccount.userName isEqualToString:@"anonymous"])) {
        urlString = [NSMutableString stringWithFormat:@"%@/",[self createUrl]];
    } else {
        urlString = [NSMutableString stringWithFormat:@"%@/",[self createUrlWithCredentials]];
    }
    
    for (NSString *component in pathArray) {
        [urlString appendFormat:@"%@/",[component encodeStringUrl:NSUTF8StringEncoding]];
    }
    [urlString appendString:[file.name encodeStringUrl:NSUTF8StringEncoding]];
    
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.url = [NSURL URLWithString:urlString];
    networkConnection.urlType = URLTYPE_FTP;
    
  	return networkConnection;
}

- (NetworkConnection *)urlForFile:(FileItem *)file
{
    NSArray *pathArray = [file.shortPath componentsSeparatedByString:@"/"];
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@/",[self createUrlWithCredentials]];
    for (NSString *component in pathArray) {
        [urlString appendFormat:@"%@/",[component encodeStringUrl:NSUTF8StringEncoding]];
    }
    [urlString appendString:[file.name encodeStringUrl:NSUTF8StringEncoding]];
    
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.url = [NSURL URLWithString:urlString];
    networkConnection.urlType = URLTYPE_FTP;
    
  	return networkConnection;
}
#endif

#pragma mark - Supported features

- (long long)supportedFeaturesAtPath:(NSString *)path
{
    long long features = CMSupportedFeaturesMaskFileDelete      |
                         CMSupportedFeaturesMaskFolderDelete    |
                         CMSupportedFeaturesMaskFileRename      |
                         CMSupportedFeaturesMaskFolderRename    |
                         CMSupportedFeaturesMaskFileMove        |
                         CMSupportedFeaturesMaskFolderMove      |
                         CMSupportedFeaturesMaskCacheImage;
    
    if ((self.userAccount.serverType == SERVER_TYPE_FTP) && (self.userAccount.boolSSL == FALSE))
    {
        features |= CMSupportedFeaturesMaskVLCPlayer       |
                    CMSupportedFeaturesMaskVideoSeek       |
                    CMSupportedFeaturesMaskAirPlay;
    }
    return features;
}

#pragma mark - Memory management

- (void)dealloc
{
    curl_easy_cleanup(curl);
}

#pragma mark - Private methods

- (BOOL)cString:(char *)cString
           size:(long)size
      forString:(NSString *)string
   fromEncoding:(NSString *)sourceEncoding
     toEncoding:(NSString *)destEncoding
{
    BOOL retCode = TRUE;
    
    /* Convert UTF-8 string to server's encoding */
    const char *utf8String = [string UTF8String];
    
    char *iconv_in = (char *)utf8String;
    char *iconv_out = (char *) cString;
    size_t iconv_in_bytes = strlen(utf8String);
    size_t iconv_out_bytes = size;
    size_t ret;
    iconv_t cd;
    
    cd = iconv_open([destEncoding cStringUsingEncoding:NSUTF8StringEncoding],[sourceEncoding cStringUsingEncoding:NSUTF8StringEncoding]);
    if ((iconv_t) -1 == cd) {
        perror("iconv_open");
        retCode = FALSE;
    }
    
    ret = iconv(cd, &iconv_in, &iconv_in_bytes, &iconv_out, &iconv_out_bytes);
    if ((size_t) -1 == ret) {
        perror("iconv");
        retCode = FALSE;
    }
    iconv_close(cd);
    
    //set end string \0
    cString[size-iconv_out_bytes]='\0';
    
    return retCode;
}

@end
