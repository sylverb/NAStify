//
//  CMQnap.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "CMQnap.h"
#import "SBNetworkActivityIndicator.h"
#import "NSStringAdditions.h"
#import "XMLDictionary.h"
#import "SSKeychain.h"

@interface CMQnap (Private)
- (void)firmwareVersion;
#ifndef APP_EXTENSION
- (void)ejectableList;
- (BOOL)isCompressed:(NSString *)type;
- (void)copyProgress;
- (void)moveProgress;
- (void)searchProgress;
- (void)extractProgress;
- (void)compressProgress;
#endif
@end

#define QNAP_FIRMWARE_4_0     @"4.0"

#define QNAP_STATUS_NOK                     0
#define QNAP_STATUS_OK                      1
#define QNAP_STATUS_FILE_EXIST              2
#define QNAP_STATUS_SESSION_EXPIRED         3
#define QNAP_STATUS_PERMISSION_DENIED       4
#define QNAP_STATUS_FILE_NOT_EXIST          5
#define QNAP_STATUS_RUNNING                 6
#define QNAP_STATUS_QUOTA_EXCEEDED          9
#define QNAP_STATUS_RECYCLE_BIN_DISABLED    16


#define HandleServerDisconnection() \
if (([JSON isKindOfClass:[NSDictionary class]]) && ([[JSON objectForKey:@"success"] boolValue] == NO)) \
{ \
    if ([[[JSON objectForKey:@"errno"] objectForKey:@"key"] isEqualToString:@"error_interrupt"]) \
    { \
        dispatch_async(dispatch_get_main_queue(), ^{ \
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys: \
                                    [NSNumber numberWithBool:NO],@"success", \
                                    @"Disconnected",@"error", \
                                    nil]]; \
         }); \
         \
        return; \
    } \
    else if ([[[JSON objectForKey:@"errno"] objectForKey:@"key"] isEqualToString:@"error_timeout"]) \
    { \
        dispatch_async(dispatch_get_main_queue(), ^{ \
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys: \
                                    [NSNumber numberWithBool:NO],@"success", \
                                    @"Connection timeout",@"error", \
                                    nil]]; \
        }); \
        \
        return; \
    } \
    else if ([[[JSON objectForKey:@"errno"] objectForKey:@"key"] isEqualToString:@"error_noprivilege"]) \
    { \
        dispatch_async(dispatch_get_main_queue(), ^{ \
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys: \
                                    [NSNumber numberWithBool:NO],@"success", \
                                    @"Connection timeout",@"error", \
                                    nil]]; \
        }); \
        \
        return; \
    } \
} \
else if (([JSON isKindOfClass:[NSDictionary class]]) && \
         ([[JSON objectForKey:@"success"] boolValue] == YES) && \
         ([[JSON objectForKey:@"status"] intValue] == QNAP_STATUS_SESSION_EXPIRED)) \
{ \
    dispatch_async(dispatch_get_main_queue(), ^{ \
        [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys: \
                                [NSNumber numberWithBool:NO],@"success", \
                                @"Connection timeout",@"error", \
                                nil]]; \
    }); \
    return; \
}

#define QNAP_ACCEPTABLE_CONTENT_TYPES @"text/html",@"text/json",@"text/plain"

@implementation CMQnap

- (id)init
{
    self = [super init];
    if (self)
    {
        self.manager = [AFHTTPRequestOperationManager manager];
        self.manager.requestSerializer = [AFHTTPRequestSerializer serializer];
        self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
        // text/html is content types returned by QNAP servers
        [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];
    }
    return self;
}


- (NSString *)createUrl
{
    NSString * url = self.userAccount.server;
    if (self.userAccount.boolSSL)
    {
        url = [NSString stringWithFormat:@"https://%@", url];
    }
    else
    {
        url = [NSString stringWithFormat:@"http://%@", url];
    }
    NSString *port = self.userAccount.port;
    if ((port == nil) || ([port length] == 0))
    {
        if (self.userAccount.boolSSL)
        {
            port = @"5001";
        }
        else
        {
            port = @"8080";
        }
    }
    
    NSString * req = [NSString stringWithFormat:@"%@:%@", url, port];
    return req;
}

- (NSString *)createUrlWithPath:(NSString *)path
{
    NSString * url = self.userAccount.server;
    if (self.userAccount.boolSSL)
    {
        url = [NSString stringWithFormat:@"https://%@", url];
    }
    else
    {
        url = [NSString stringWithFormat:@"http://%@", url];
    }
    NSString *port = self.userAccount.port;
    if ((port == nil) || ([port length] == 0))
    {
        if (self.userAccount.boolSSL)
        {
            port = @"5001";
        }
        else
        {
            port = @"8080";
        }
    }
    
    return [NSString stringWithFormat:@"%@:%@/%@", url, port, path];
}

- (NSString *)createUrlWithCredentials
{
    NSString *url = self.userAccount.server;
    NSString *userName = self.userAccount.userName;
    NSString *password = [SSKeychain passwordForService:self.userAccount.uuid
                                                account:@"password"];
    if (!userName)
    {
        userName = @"guest";
        password = @"";
    }
    
    if (self.userAccount.boolSSL)
    {
        url = [NSString stringWithFormat:@"https://%@:%@@%@", userName, password, url];
    }
    else
    {
        url = [NSString stringWithFormat:@"http://%@:%@@%@", userName, password, url];
    }
    
    NSString *port = self.userAccount.port;
    if ((port == nil) || ([port length] == 0))
    {
        if (self.userAccount.boolSSL)
        {
            port = @"5001";
        }
        else
        {
            port = @"8080";
        }
    }
    
    NSString * req = [NSString stringWithFormat:@"%@:%@", url, port];
    return req;
}

#pragma mark - Server Info

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           [NSString stringWithFormat:NSLocalizedString(@"Server Model : QNAP %@",nil), serverModel],
                           [NSString stringWithFormat:NSLocalizedString(@"Firmware : %@",nil), serverFirmware],
                           [NSString stringWithFormat:NSLocalizedString(@"Hostname : %@",nil), serverHostname],
                           nil];
    return serverInfo;
}


#pragma mark - login/logout management

- (BOOL)login
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id response) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        
        NSDictionary *xml = [NSDictionary dictionaryWithXMLData:response];
        if ([[xml valueForKeyPath:@"authPassed"] boolValue])
        {
            sID = [xml valueForKeyPath:@"authSid"];
            
            [self firmwareVersion];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        @"Invalid user/password",@"error",
                                        nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO],@"success",
                                    [error description],@"error",
                                    nil]];
        });
    };

    self.manager.securityPolicy.allowInvalidCertificates = self.userAccount.acceptUntrustedCertificate;
    self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    NSString *password = [SSKeychain passwordForService:self.userAccount.uuid
                                                account:@"password"];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            self.userAccount.userName,@"user",
                            [password ezEncode],@"pwd",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

    [self.manager POST:[self createUrlWithPath:@"cgi-bin/authLogin.cgi"]
            parameters:params
               success:successBlock
               failure:failureBlock];

    return YES;
}

- (BOOL)logout
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogout:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:YES],@"success",
                                     nil]];
        });
    };

    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogout:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],@"success",
                                     [error description],@"error",
                                     nil]];
        });
    };

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            sID,@"sid",
                            @"1",@"logout",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

    [self.manager POST:[self createUrlWithPath:@"cgi-bin/authLogout.cgi"]
            parameters:params
               success:successBlock
               failure:failureBlock];

    return YES;
}

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
	if ([folder.path isEqualToString:@"/"])
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if (([JSON isKindOfClass:[NSDictionary class]]) && ([JSON objectForKey:@"status"]))
            {
                NSInteger status = [[JSON objectForKey:@"status"] integerValue];
                switch (status) {
                    case QNAP_STATUS_PERMISSION_DENIED:
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        [NSNumber numberWithBool:NO],@"success",
                                                        folder.path,@"path",
                                                        @"Permission denied",@"error",
                                                        nil]];
                        });
                        break;
                    }
                        
                    default:
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        [NSNumber numberWithBool:NO],@"success",
                                                        folder.path,@"path",
                                                        [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                        nil]];
                        });
                        break;
                    }
                }
            }
            else
            {
                NSMutableArray *filesOutputArray = nil;
                if ([JSON isKindOfClass:[NSArray class]])
                {
                    /* Build dictionary with items */
                    filesOutputArray = [NSMutableArray arrayWithCapacity:[JSON count]];
                    for (NSDictionary *file in JSON)
                    {
                        // cls : r => read only
                        //       w => read write
                        bool writeAccess = NO;
                        if ([[file objectForKey:@"cls"] isEqualToString:@"w"])
                        {
                            writeAccess = YES;
                        }
                        
                        NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:YES],@"isdir",
                                                  [file objectForKey:@"text"],@"filename",
                                                  [file objectForKey:@"id"],@"path",
                                                  [NSNumber numberWithBool:NO],@"iscompressed",
                                                  [NSNumber numberWithBool:writeAccess],@"writeaccess",
                                                  nil];
                        [filesOutputArray addObject:dictItem];
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                    [NSNumber numberWithBool:YES],@"success",
                                                    folder.path,@"path",
                                                    filesOutputArray,@"filesList",
                                                    nil]];
                    });
                    
#ifndef APP_EXTENSION
                    // get ejectable list
                    [self ejectableList];
#endif
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                    [NSNumber numberWithBool:NO],@"success",
                                                    folder.path,@"path",
                                                    nil]];
                    });
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            folder.path,@"path",
                                            [error description],@"error",
                                            nil]];
            });
        };

        self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
        // text/html is content types returned by QNAP servers
        [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"share_root",@"node",
                                nil];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=get_tree&sid=%@&is_iso=0",sID]]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
	}
    else
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

            HandleServerDisconnection();
            
            if (([JSON isKindOfClass:[NSDictionary class]]) && ([JSON objectForKey:@"status"]))
            {
                NSInteger status = [[JSON objectForKey:@"status"] integerValue];
                switch (status) {
                    case QNAP_STATUS_PERMISSION_DENIED:
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        [NSNumber numberWithBool:NO],@"success",
                                                        folder.path,@"path",
                                                        @"Permission denied",@"error",
                                                        nil]];
                        });
                        break;
                    }
                        
                    default:
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        [NSNumber numberWithBool:NO],@"success",
                                                        folder.path,@"path",
                                                        [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                        nil]];
                        });
                        break;
                    }
                }
            }
            else
            {
                NSMutableArray *filesOutputArray = [NSMutableArray array];
                for (NSDictionary *file in [JSON objectForKey:@"datas"])
                {
                    NSNumber *size = [NSNumber numberWithLongLong:[[file objectForKey:@"filesize"] longLongValue]];
                    
                    BOOL iscompressed = [self isCompressed:[[file objectForKey:@"filename"] pathExtension]];
                    
                    NSInteger userPermission = [[file objectForKey:@"privilege"] integerValue] / 100;
                    BOOL writeAccess = userPermission & 2; // Posix w rights
                    
                    NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [file objectForKey:@"isfolder"],@"isdir",
                                              [file objectForKey:@"filename"],@"filename",
                                              size,@"filesizenumber",
                                              [file objectForKey:@"owner"],@"owner",
                                              [NSNumber numberWithBool:iscompressed],@"iscompressed",
                                              [NSNumber numberWithBool:writeAccess],@"writeaccess",
                                              [file objectForKey:@"epochmt"],@"date",
                                              [[file objectForKey:@"filename"] pathExtension],@"type",
                                              nil];
                    
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
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            folder.path,@"path",
                                            [error description],@"error",
                                            nil]];
            });
        };

        self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
        // text/html is content types returned by QNAP servers
        [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

        CFStringRef escapedPath = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                          (CFStringRef)folder.path,
                                                                          NULL,
                                                                          (CFStringRef)@";/?:@&=+$,",
                                                                          kCFStringEncodingUTF8);
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"0",@"start",
                                @"5000",@"limit",
                                @"filename",@"sort", // filename,mt,filesize,type
                                @"ASC",@"dir", // DESC,ASC
                                nil];
        
        

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=get_list&sid=%@&list_mode=all&path=%@",sID,escapedPath]]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
	}
}

#pragma mark - space info management

- (void)spaceInfoAtPath:(FileItem *)folder
{
    if (![folder.path isEqualToString:@"/"])
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"status"] integerValue] == QNAP_STATUS_OK)
            {
                NSNumber *total = [NSNumber numberWithInt:0];
                NSNumber *free = [NSNumber numberWithLongLong:1024 * [[JSON objectForKey:@"free_size"] longLongValue]];
                
                long long freeLong = [free longLongValue];
                long long usedLong = 1024 * [[JSON objectForKey:@"used_size"] longLongValue];
                long long totalLong = freeLong + usedLong;
                total = [NSNumber numberWithLongLong:totalLong];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMSpaceInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                total,@"totalspace",
                                                free,@"freespace",
                                                nil]];
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMSpaceInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                [[JSON objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                                nil]];
                });
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMSpaceInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error description],@"error",
                                            nil]];
            });
        };
        
        self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
        // text/html is content types returned by QNAP servers
        [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                folder.path,@"path",
                                nil];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=get_disk_info&sid=%@",sID]]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
    }
}

#pragma mark - Folder creation management

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        NSInteger status = [[JSON objectForKey:@"status"] integerValue];
        switch (status)
        {
            case QNAP_STATUS_OK:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES],@"success",
                                                   nil]];
                });
                break;
            }
            case QNAP_STATUS_FILE_EXIST:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   @"File already exists",@"error",
                                                   nil]];
                });
                break;
            }
            case QNAP_STATUS_PERMISSION_DENIED:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   @"Permission denied",@"error",
                                                   nil]];
                });
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                   nil]];
                });
                break;
            }
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [error description],@"error",
                                           nil]];
        });
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            folder.path,@"dest_path",
                            folderName,@"dest_folder",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=createdir&sid=%@",sID]]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

#pragma mark - delete management

#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files
{
    NSString *path = nil;
    // QNAP devices can only delete files in the same folder, check that it's the case
    for (FileItem *fileItem in files)
    {
        if (path == nil)
        {
            path = fileItem.shortPath;
        }
        else if (![path isEqualToString:fileItem.shortPath])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 @"Can't delete files in different folders",@"error",
                                                 nil]];
            });
            
            return;
        }
    }

    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        NSInteger status = [[JSON objectForKey:@"status"] integerValue];
        switch (status)
        {
            case QNAP_STATUS_OK:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:YES],@"success",
                                                     nil]];
                });
                break;
            }
            case QNAP_STATUS_PERMISSION_DENIED:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     @"Permission denied",@"error",
                                                     nil]];
                });
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                     nil]];
                });
                break;
            }
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             [error description],@"error",
                                             nil]];
        });
    };

    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    NSMutableURLRequest *request = [self.manager.requestSerializer requestWithMethod:@"POST"
                                                                           URLString:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=delete&sid=%@",sID]]
                                                                          parameters:nil
                                                                               error:nil];
    
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (FileItem *fileItem in files)
    {
        [mutablePairs addObject:[NSString stringWithFormat:@"file_name=%@",[fileItem.name encodeString:NSUTF8StringEncoding]]];
    }
    [mutablePairs addObject:[NSString stringWithFormat:@"file_total=%ld",(long)[files count]]];
    [mutablePairs addObject:[NSString stringWithFormat:@"path=%@",[path encodeString:NSUTF8StringEncoding]]];
    
    NSData *httpBody = [[mutablePairs componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:httpBody];

    AFHTTPRequestOperation* operation =[self.manager HTTPRequestOperationWithRequest:request
                                                                             success:successBlock
                                                                             failure:failureBlock];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager.operationQueue addOperation:operation];
}
#endif

#pragma mark - copy management

#ifndef APP_EXTENSION
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    NSString *path = nil;
    // QNAP devices can only copy files in the same folder, check that it's the case
    for (FileItem *fileItem in files)
    {
        if (path == nil)
        {
            path = fileItem.shortPath;
        }
        else if (![path isEqualToString:fileItem.shortPath])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               @"Can't copy files from different folders",@"error",
                                               nil]];
            });
            return;
        }
    }
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        NSInteger status = [[JSON objectForKey:@"status"] integerValue];
        switch (status)
        {
            case QNAP_STATUS_OK:
            {
                copyTaskID = [JSON objectForKey:@"pid"];
                
                [self performSelector:@selector(copyProgress) withObject:nil afterDelay:0.2];
                break;
            }
            case QNAP_STATUS_PERMISSION_DENIED:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   @"Permission denied",@"error",
                                                   nil]];
                });
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                   nil]];
                });
                break;
            }
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [error description],@"error",
                                           nil]];
        });
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    NSMutableURLRequest *request = [self.manager.requestSerializer requestWithMethod:@"POST"
                                                                           URLString:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=copy&sid=%@",sID]]
                                                                          parameters:nil
                                                                               error:nil];

    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (FileItem *fileItem in files)
    {
        [mutablePairs addObject:[NSString stringWithFormat:@"source_file=%@",[fileItem.name encodeString:NSUTF8StringEncoding]]];
    }
    [mutablePairs addObject:[NSString stringWithFormat:@"source_total=%ld",(long)[files count]]];
    [mutablePairs addObject:[NSString stringWithFormat:@"source_path=%@",[path encodeString:NSUTF8StringEncoding]]];
    [mutablePairs addObject:[NSString stringWithFormat:@"dest_path=%@",[destFolder.path encodeString:NSUTF8StringEncoding]]];
    [mutablePairs addObject:[NSString stringWithFormat:@"mode=%@",overwrite?@"0":@"1"]]; // 0 : overwrite / 1 : skip
    
    NSData *httpBody = [[mutablePairs componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:httpBody];
    
    AFHTTPRequestOperation* operation =[self.manager HTTPRequestOperationWithRequest:request
                                                                             success:successBlock
                                                                             failure:failureBlock];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager.operationQueue addOperation:operation];
}

- (void)copyProgress
{
    if (copyTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            NSInteger status = [[JSON objectForKey:@"status"] integerValue];
            switch (status) {
                case QNAP_STATUS_OK:
                {
                    float progress = [[JSON objectForKey:@"percent"] floatValue] / 100;
                    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithFloat:progress]
                                                                                       forKey:@"progress"];
                    if ([JSON objectForKey:@"filename"])
                    {
                        [userInfo addEntriesFromDictionary:
                         [NSDictionary dictionaryWithObject:[JSON objectForKey:@"filename"]
                                                     forKey:@"info"]];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCopyProgress:userInfo];
                    });
                    
                    if (progress < 1.0)
                    {
                        // Update progress
                        [self performSelector:@selector(copyProgress)
                                   withObject:nil
                                   afterDelay:2];
                    }
                    else
                    {
                        // Copy is now finished
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:YES],@"success",
                                                           nil]];
                        });
                    }
                    break;
                }
                default:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [JSON objectForKey:@"success"],@"success",
                                                       [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                       nil]];
                    });
                    break;
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error description],@"error",
                                               nil]];
            });
        };
        
        self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
        // text/html is content types returned by QNAP servers
        [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

        [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=get_copy_status&sid=%@&pid=%@",sID,copyTaskID]]
               parameters:nil
                  success:successBlock
                  failure:failureBlock];
    }
}

- (void)cancelCopyTask
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        copyTaskID = nil;
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        copyTaskID = nil;
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=cancel_copy&sid=%@&pid=%@",sID,copyTaskID]]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}
#endif

#pragma mark - move management

#ifndef APP_EXTENSION
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    NSString *path = nil;
    // QNAP devices can only copy files in the same folder, check that it's the case
    for (FileItem *fileItem in files)
    {
        if (path == nil)
        {
            path = fileItem.shortPath;
        }
        else if (![path isEqualToString:fileItem.shortPath])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               @"Can't copy files from different folders",@"error",
                                               nil]];
            });
            
            return;
        }
    }
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        NSInteger status = [[JSON objectForKey:@"status"] integerValue];
        switch (status)
        {
            case QNAP_STATUS_OK:
            {
                moveTaskID = [JSON objectForKey:@"pid"];
                
                [self performSelector:@selector(moveProgress) withObject:nil afterDelay:0.2];
                break;
            }
            case QNAP_STATUS_PERMISSION_DENIED:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   @"Permission denied",@"error",
                                                   nil]];
                });
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                   nil]];
                });
                break;
            }
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [error description],@"error",
                                           nil]];
        });
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    NSMutableURLRequest *request = [self.manager.requestSerializer requestWithMethod:@"POST"
                                                                           URLString:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=move&sid=%@",sID]]
                                                                          parameters:nil
                                                                               error:nil];
    
    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (FileItem *fileItem in files)
    {
        [mutablePairs addObject:[NSString stringWithFormat:@"source_file=%@",[fileItem.name encodeString:NSUTF8StringEncoding]]];
    }
    [mutablePairs addObject:[NSString stringWithFormat:@"source_total=%ld",(long)[files count]]];
    [mutablePairs addObject:[NSString stringWithFormat:@"source_path=%@",[path encodeString:NSUTF8StringEncoding]]];
    [mutablePairs addObject:[NSString stringWithFormat:@"dest_path=%@",[destFolder.path encodeString:NSUTF8StringEncoding]]];
    [mutablePairs addObject:[NSString stringWithFormat:@"mode=%@",overwrite?@"0":@"1"]]; // 0 : overwrite / 1 : skip
    
    NSData *httpBody = [[mutablePairs componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:httpBody];
    
    AFHTTPRequestOperation* operation =[self.manager HTTPRequestOperationWithRequest:request
                                                                             success:successBlock
                                                                             failure:failureBlock];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager.operationQueue addOperation:operation];
}

- (void)moveProgress
{
    if (moveTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            NSInteger status = [[JSON objectForKey:@"status"] integerValue];
            switch (status) {
                case QNAP_STATUS_OK:
                {
                    float progress = [[JSON objectForKey:@"percent"] floatValue] / 100;
                    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithFloat:progress]
                                                                                       forKey:@"progress"];
                    if ([JSON objectForKey:@"filename"])
                    {
                        [userInfo addEntriesFromDictionary:
                         [NSDictionary dictionaryWithObject:[JSON objectForKey:@"filename"]
                                                     forKey:@"info"]];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMMoveProgress:userInfo];
                    });
                    
                    if (progress < 1.0)
                    {
                        // Update progress
                        [self performSelector:@selector(moveProgress)
                                   withObject:nil
                                   afterDelay:2];
                    }
                    else
                    {
                        // Move is now finished
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:YES],@"success",
                                                           nil]];
                        });
                    }
                    break;
                }
                default:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [JSON objectForKey:@"success"],@"success",
                                                       [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                       nil]];
                    });
                    break;
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error description],@"error",
                                               nil]];
            });
        };
        
        self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
        // text/html is content types returned by QNAP servers
        [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

        [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=get_move_status&sid=%@&pid=%@",sID,moveTaskID]]
               parameters:nil
                  success:successBlock
                  failure:failureBlock];
    }
}

- (void)cancelMoveTask
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        moveTaskID = nil;
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        moveTaskID = nil;
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=cancel_move&sid=%@&pid=%@",sID,moveTaskID]]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}
#endif

#pragma mark - Renaming management

#ifndef APP_EXTENSION
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        NSInteger status = [[JSON objectForKey:@"status"] integerValue];
        switch (status)
        {
            case QNAP_STATUS_OK:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:YES],@"success",
                                             nil]];
                });
                break;
            }
            case QNAP_STATUS_FILE_EXIST:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             @"File already exists",@"error",
                                             nil]];
                });
                break;
            }
            case QNAP_STATUS_PERMISSION_DENIED:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             @"Permission denied",@"error",
                                             nil]];
                });
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                             nil]];
                });
                break;
            }
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],@"success",
                                     [error description],@"error",
                                     nil]];
        });
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            folder.path,@"path",
                            oldFile.name,@"source_name",
                            newName,@"dest_name",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=rename&sid=%@",sID]]
            parameters:params
               success:successBlock
               failure:failureBlock];
}
#endif

#pragma mark - Eject management

#ifndef APP_EXTENSION
- (void)ejectableList
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id response) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSDictionary *xml = [NSDictionary dictionaryWithXMLData:response];

        id xmlElement = [xml valueForKeyPath:@"func.ownContent.externalDevice.device"];

        NSMutableArray *devicesArray = [[NSMutableArray alloc] init];
        
        if ([xmlElement isKindOfClass:[NSArray class]])
        {
            NSArray *devicesServer = (NSArray *)xmlElement;
            for (NSDictionary *dict in devicesServer)
            {
                NSDictionary *deviceElement = [NSDictionary dictionaryWithObjectsAndKeys:
                                               [dict objectForKey:@"name"],@"folder",
                                               [dict objectForKey:@"USBandSATA_ListId"],@"ejectname",
                                               nil];
                
                [devicesArray addObject:deviceElement];
            }
        }
        else
        {
            NSDictionary *deviceServer = (NSDictionary *)xmlElement;
            
            NSDictionary *deviceElement = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [deviceServer objectForKey:@"name"],@"folder",
                                           [deviceServer objectForKey:@"USBandSATA_ListId"],@"ejectname",
                                           nil];
            
            [devicesArray addObject:deviceElement];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:YES],@"success",
                                            devicesArray,@"ejectablelist",
                                            nil]];
        });
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error description],@"error",
                                            nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"getExternalDev",@"func",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];

    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/devices/devRequest.cgi?sid=%@",sID]]
            parameters:params
               success:successBlock
               failure:failureBlock];
}
#endif

#ifndef APP_EXTENSION
- (void)ejectFile:(FileItem *)fileItem
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id response) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:YES],@"success",
                                            nil]];
        });
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error description],@"error",
                                            nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"eject_all",@"todo",
                            fileItem.ejectName,@"disk_no",
                            @"usb_disk",@"subfunc",
                            @"USB",@"disk_page",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/devices/devRequest.cgi?sid=%@",sID]]
            parameters:params
               success:successBlock
               failure:failureBlock];
}
#endif

#pragma mark - Extract management

#ifndef APP_EXTENSION
- (void)extractFiles:(NSArray *)files toFolder:(FileItem *)folder withPassword:(NSString *)password overwrite:(BOOL)overwrite extractWithFolder:(BOOL)extractFolders
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        NSInteger status = [[JSON objectForKey:@"status"] integerValue];
        switch (status)
        {
            case QNAP_STATUS_OK:
            {
                extractTaskID = [JSON objectForKey:@"pid"];
                
                [self performSelector:@selector(extractProgress) withObject:nil afterDelay:0.2];
                break;
            }
            case QNAP_STATUS_PERMISSION_DENIED:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:NO],@"success",
                                                      @"Permission denied",@"error",
                                                      nil]];
                });
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:NO],@"success",
                                                      [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                      nil]];
                });
                break;
            }
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithBool:NO],@"success",
                                              [error description],@"error",
                                              nil]];
        });
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    NSString *pwd = @"";
    if (password && ([password length] != 0))
    {
        pwd = password;
    }
    
    FileItem *fileItem = [files firstObject];

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"extract_all",@"mode",
                            pwd,@"pwd",
                            extractFolders?@"full":@"none",@"path_mode",
                            fileItem.path,@"extract_file",
                            @"UTF-8",@"code_page",
                            overwrite?@"0":@"1",@"overwrite",
                            folder.path,@"dest_path",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=extract&sid=%@",sID]]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

- (void)extractProgress
{
    if (extractTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            NSInteger status = [[JSON objectForKey:@"status"] integerValue];
            switch (status)
            {
                case QNAP_STATUS_NOK:
                {
                    // May happen when cancelling task
                    break;
                }
                case QNAP_STATUS_OK:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          [NSNumber numberWithBool:YES],@"success",
                                                          nil]];
                    });
                    break;
                }
                case QNAP_STATUS_RUNNING:
                {
                    // Update progress
                    [self performSelector:@selector(extractProgress) withObject:nil afterDelay:2];
                    break;
                }
                default:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          [NSNumber numberWithBool:NO],@"success",
                                                          [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                          nil]];
                    });
                    break;
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:NO],@"success",
                                                  [error description],@"error",
                                                  nil]];
            });
        };
        
        self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
        // text/html is content types returned by QNAP servers
        [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=get_extract_status&sid=%@&pid=%@",sID,extractTaskID]]
               parameters:nil
                  success:successBlock
                  failure:failureBlock];
    }
}

- (void)cancelExtractTask
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        extractTaskID = nil;
        
        NSInteger status = [[JSON objectForKey:@"status"] integerValue];
        switch (status)
        {
            case QNAP_STATUS_NOK:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:NO],@"success",
                                                      @"Cancel failed",@"error",
                                                      nil]];
                });
                break;
            }
            case QNAP_STATUS_OK:
            {
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:NO],@"success",
                                                      [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                      nil]];
                });
                break;
            }
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithBool:NO],@"success",
                                              [error description],@"error",
                                              nil]];
        });
        
        extractTaskID = nil;
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=cancel_extract&sid=%@&pid=%@",sID,extractTaskID]]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}
#endif

#pragma mark - compress management

#ifndef APP_EXTENSION
- (void)compressFiles:(NSArray *)files toArchive:(NSString *)archive archiveType:(ARCHIVE_TYPE)archiveType compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel password:(NSString *)password overwrite:(BOOL)overwrite
{
    NSString *path = nil;
    // QNAP devices can only compress files in the same folder, check that it's the case
    for (FileItem *fileItem in files)
    {
        if (path == nil)
        {
            path = fileItem.shortPath;
        }
        else if (![path isEqualToString:fileItem.shortPath])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   @"Can't compress files from different folders",@"error",
                                                   nil]];
            });
            
            return;
        }
    }

    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        NSInteger status = [[JSON objectForKey:@"status"] integerValue];
        switch (status)
        {
            case QNAP_STATUS_OK:
            {
                compressTaskID = [JSON objectForKey:@"pid"];
                
                [self performSelector:@selector(compressProgress) withObject:nil afterDelay:0.2];
                break;
            }
            case QNAP_STATUS_PERMISSION_DENIED:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       @"Permission denied",@"error",
                                                       nil]];
                });
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                       nil]];
                });
                break;
            }
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error description],@"error",
                                               nil]];
        });
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    NSMutableArray *mutablePairs = [NSMutableArray array];
    for (FileItem *fileItem in files)
    {
        [mutablePairs addObject:[NSString stringWithFormat:@"compress_file=%@",fileItem.name]];//[fileItem.name encodeString:NSUTF8StringEncoding]]];
    }
    NSString *urlparams = [mutablePairs componentsJoinedByString:@"&"];

    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   [[archive lastPathComponent] stringByDeletingPathExtension],@"compress_name",
                                   path,@"path",
                                   [NSNumber numberWithInteger:[files count]],@"total",
                                   sID,@"sid",
                                   nil];
    switch (archiveType) {
        case ARCHIVE_TYPE_ZIP:
        {
            [params addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                              @"zip",@"type",
                                              nil]];
            break;
        }
        case ARCHIVE_TYPE_7Z:
        {
            [params addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                              @"7z",@"type",
                                              nil]];
            break;
        }
        default:
            break;
    }


    switch (compressionLevel) {
        case ARCHIVE_COMPRESSION_LEVEL_BEST:
        {
            [params addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                              @"large",@"level",
                                              nil]];
            break;
        }
        case ARCHIVE_COMPRESSION_LEVEL_FASTEST:
        {
            [params addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                              @"fast",@"level",
                                              nil]];
            break;
        }
        case ARCHIVE_COMPRESSION_LEVEL_NORMAL:
        {
            [params addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                              @"normal",@"level",
                                              nil]];
            break;
        }
        default:
            break;
    }

    if (overwrite)
    {
        [params addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                          @"1",@"mode",
                                          nil]];
    }
    else
    {
        [params addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                          @"2",@"mode",
                                          nil]];
    }
    if (password && ([password length] != 0))
    {
        [params addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                          password,@"pwd",
                                          nil]];
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?&func=compress&%@",urlparams]]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

- (void)compressProgress
{
    if (compressTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            NSInteger status = [[JSON objectForKey:@"status"] integerValue];
            switch (status)
            {
                case QNAP_STATUS_NOK:
                {
                    // May happen when cancelling task
                    break;
                }
                case QNAP_STATUS_OK:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:YES],@"success",
                                                           nil]];
                    });
                    break;
                }
                case QNAP_STATUS_RUNNING:
                {
                    // Update progress
                    [self performSelector:@selector(compressProgress) withObject:nil afterDelay:2];
                    break;
                }
                default:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:NO],@"success",
                                                           [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                           nil]];
                    });
                    break;
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [error description],@"error",
                                                   nil]];
            });
        };
        
        self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
        // text/html is content types returned by QNAP servers
        [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=get_compress_status&sid=%@&pid=%@",sID,compressTaskID]]
               parameters:nil
                  success:successBlock
                  failure:failureBlock];
    }
}

- (void)cancelCompressTask
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        compressTaskID = nil;
        
        NSInteger status = [[JSON objectForKey:@"status"] integerValue];
        switch (status)
        {
            case QNAP_STATUS_NOK:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       @"Cancel failed",@"error",
                                                       nil]];
                });
                break;
            }
            case QNAP_STATUS_OK:
            {
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                       nil]];
                });
                break;
            }
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        compressTaskID = nil;
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=cancel_compress&sid=%@&pid=%@",sID,compressTaskID]]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}
#endif

#pragma mark - search management

- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        if (([JSON isKindOfClass:[NSDictionary class]]) && ([JSON objectForKey:@"status"]))
        {
            NSInteger status = [[JSON objectForKey:@"status"] integerValue];
            switch (status) {
                case QNAP_STATUS_PERMISSION_DENIED:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         @"Permission denied",@"error",
                                                         nil]];
                    });
                    break;
                }
                    
                default:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                         nil]];
                    });
                    break;
                }
            }
        }
        else
        {
            if ([[JSON objectForKey:@"datas"] isKindOfClass:[NSArray class]])
            {
                NSMutableArray *filesOutputArray = [NSMutableArray array];
                for (NSDictionary *file in [JSON objectForKey:@"datas"])
                {
                    NSNumber *size = [NSNumber numberWithLongLong:[[file objectForKey:@"filesize"] longLongValue]];
                    
                    BOOL iscompressed = [self isCompressed:[[file objectForKey:@"filename"] pathExtension]];
                    
                    NSInteger userPermission = [[file objectForKey:@"privilege"] integerValue] / 100;
                    BOOL writeAccess = userPermission & 2; // Posix w rights
                    
                    NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [file objectForKey:@"isfolder"],@"isdir",
                                              [[file objectForKey:@"filename"] lastPathComponent],@"filename",
                                              [file objectForKey:@"filename"],@"path",
                                              size,@"filesizenumber",
                                              [file objectForKey:@"owner"],@"owner",
                                              [NSNumber numberWithBool:iscompressed],@"iscompressed",
                                              [NSNumber numberWithBool:writeAccess],@"writeaccess",
                                              [file objectForKey:@"epochmt"],@"date",
                                              [[file objectForKey:@"filename"] pathExtension],@"type",
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
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     @"Search failed",@"error",
                                                     nil]];
                });
            }
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             [error description],@"error",
                                             nil]];
        });
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"0",@"start",
                            @"5000",@"limit",
                            @"filename",@"sort",
                            @"ASC",@"dir",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=search&sid=%@&source_path=%@&keyword=%@",
                                                sID,
                                                [folder.path encodeString:NSUTF8StringEncoding],
                                                [searchString encodeString:NSUTF8StringEncoding]]]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

#pragma mark - Sharing management

#ifndef APP_EXTENSION
- (void)shareFilesSettings:(NSArray *)files ssid:(NSString *)ssid duration:(NSTimeInterval)duration password:(NSString *)password
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        if (([JSON isKindOfClass:[NSDictionary class]]) && ([JSON objectForKey:@"status"]))
        {
            NSInteger status = [[JSON objectForKey:@"status"] integerValue];
            switch (status)
            {
                case QNAP_STATUS_OK:
                {
                    break;
                }
                case QNAP_STATUS_PERMISSION_DENIED:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        [NSNumber numberWithBool:NO],@"success",
                                                        @"Permission denied",@"error",
                                                        nil]];
                    });
                    break;
                }
                default:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        [NSNumber numberWithBool:NO],@"success",
                                                        [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                        nil]];
                    });
                    break;
                }
            }
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                @"Sharing failed",@"error",
                                                nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error description],@"error",
                                            nil]];
        });
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];
    
    NSMutableURLRequest *request = [self.manager.requestSerializer requestWithMethod:@"POST"
                                                                           URLString:[self createUrlWithPath:@"cgi-bin/filemanager/utilRequest.cgi?func=update_share_link"]
                                                                          parameters:nil
                                                                               error:nil];
    
    NSMutableArray *mutablePairs = [NSMutableArray array];
    
    [mutablePairs addObject:@"file_total=1"];
    [mutablePairs addObject:[NSString stringWithFormat:@"ssids=%@",ssid]];
    [mutablePairs addObject:@"option=1"];
    if (self.userAccount.boolSSL)
    {
        [mutablePairs addObject:@"ssl=true"];
    }
    else
    {
        [mutablePairs addObject:@"ssl=false"];
    }
    [mutablePairs addObject:[NSString stringWithFormat:@"hostname=%@",self.userAccount.server]];

    [mutablePairs addObject:@"include_access_code=false"];
    [mutablePairs addObject:@"allowUpload=false"];
    FileItem *file = [files objectAtIndex:0];
    [mutablePairs addObject:[NSString stringWithFormat:@"link_name=%@",file.name]];
    
    if (duration == 0)
    {
        [mutablePairs addObject:@"valid_duration=forever"];
    }
    else
    {
        NSDate *date = [[NSDate alloc]init];
        NSDate *expireDate = [date dateByAddingTimeInterval:duration];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy/MM/dd HH:mm"];
        
        [mutablePairs addObject:@"valid_duration=specific_time"];
        [mutablePairs addObject:[NSString stringWithFormat:@"datetime=%@",[[formatter stringFromDate:expireDate] encodeString:NSUTF8StringEncoding]]];
    }
    
    if ((password == nil) || (password.length == 0))
    {
        [mutablePairs addObject:@"access_enabled=false"];
        [mutablePairs addObject:@"access_code="];
    }
    else
    {
        [mutablePairs addObject:@"access_enabled=true"];
        [mutablePairs addObject:[NSString stringWithFormat:@"access_code=%@",[password encodeString:NSUTF8StringEncoding]]];
    }
    [mutablePairs addObject:[NSString stringWithFormat:@"sid=%@",sID]];
    
    NSData *httpBody = [[mutablePairs componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:httpBody];
    
    AFHTTPRequestOperation* operation = [self.manager HTTPRequestOperationWithRequest:request
                                                                              success:successBlock
                                                                              failure:failureBlock];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager.operationQueue addOperation:operation];
}

- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password
{
    NSString *path = nil;
    // QNAP devices can only delete files in the same folder, check that it's the case
    for (FileItem *fileItem in files)
    {
        if (path == nil)
        {
            path = fileItem.shortPath;
        }
        else if (![path isEqualToString:fileItem.shortPath])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                @"Can't share files in different folders",@"error",
                                                nil]];
            });
            
            return;
        }
    }

    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        if (([JSON isKindOfClass:[NSDictionary class]]) && ([JSON objectForKey:@"status"]))
        {
            NSInteger status = [[JSON objectForKey:@"status"] integerValue];
            switch (status)
            {
                case QNAP_STATUS_OK:
                {
                    if ((password.length != 0) || (duration !=0))
                    {
                        [self shareFilesSettings:files
                                            ssid:[JSON objectForKey:@"ssid"]
                                        duration:duration
                                        password:password];
                    }
                    
                    NSArray *shares = [JSON objectForKey:@"links"];
                    NSMutableString *shareString = [NSMutableString string];
                    for (NSDictionary *share in shares)
                    {
                        [shareString appendFormat:@"%@ : %@\r\n",[[share objectForKey:@"filename"] lastPathComponent], [share objectForKey:@"link_url"]];
                    }
                    if (password.length != 0)
                    {
                        [shareString appendFormat:NSLocalizedString(@"Use password : %@\r\n",nil),password];

                    }
                    if (duration != 0)
                    {
                        NSDate *date = [[NSDate alloc]init];
                        NSDate *expireDate = [date dateByAddingTimeInterval:duration];
                        
                        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                        [formatter setDateFormat:@"yyyy/MM/dd HH:mm"];
                        
                        [shareString appendFormat:NSLocalizedString(@"Links are valid until %@\r\n",nil),[formatter stringFromDate:expireDate]];
                    }
                    [shareString appendString:NSLocalizedString(@"\r\nShared using NAStify\r\n",nil)];

                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        [NSNumber numberWithBool:YES],@"success",
                                                        shareString,@"shares",
                                                        nil]];
                    });

                    break;
                }
                case QNAP_STATUS_PERMISSION_DENIED:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         @"Permission denied",@"error",
                                                         nil]];
                    });
                    break;
                }
                default:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                         nil]];
                    });
                    break;
                }
            }
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                @"Sharing failed",@"error",
                                                nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error description],@"error",
                                            nil]];
        });
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];
    
    NSMutableURLRequest *request = [self.manager.requestSerializer requestWithMethod:@"POST"
                                                                           URLString:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=get_share_link&sid=%@",
                                                                                      sID]]
                                                                          parameters:nil
                                                                               error:nil];
    
    NSMutableArray *mutablePairs = [NSMutableArray array];
    
    [mutablePairs addObject:@"download_type=create_download_link"];
    [mutablePairs addObject:[NSString stringWithFormat:@"hostname=%@",self.userAccount.server]];
    if (self.userAccount.boolSSL)
    {
        [mutablePairs addObject:@"ssl=true"];
    }
    else
    {
        [mutablePairs addObject:@"ssl=false"];
    }
    [mutablePairs addObject:@"include_access_code=false"];
    [mutablePairs addObject:@"valid_duration=forever"];
    [mutablePairs addObject:@"access_enabled=false"];
    [mutablePairs addObject:@"access_code="];
    
    for (FileItem *fileItem in files)
    {
        [mutablePairs addObject:[NSString stringWithFormat:@"file_name=%@",[fileItem.name encodeString:NSUTF8StringEncoding]]];
    }
    [mutablePairs addObject:[NSString stringWithFormat:@"file_total=%ld",(long)[files count]]];
    [mutablePairs addObject:[NSString stringWithFormat:@"path=%@",[path encodeString:NSUTF8StringEncoding]]];
    [mutablePairs addObject:@"network_type=internet"];
    [mutablePairs addObject:@"c=1"];
    
    NSData *httpBody = [[mutablePairs componentsJoinedByString:@"&"] dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:httpBody];
    
    AFHTTPRequestOperation* operation = [self.manager HTTPRequestOperationWithRequest:request
                                                                              success:successBlock
                                                                              failure:failureBlock];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager.operationQueue addOperation:operation];
}

- (SHARING_VALIDITY_UNIT)shareValidityUnit
{
    return SHARING_VALIDITY_UNIT_HOUR;
}
#endif

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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error description],@"error",
                                               nil]];
        });
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    NSString *filename = [file.name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            file.isDir?@"1":@"0",@"isFolder",
                            @"download",@"func",
                            sID,@"sid",
                            @"1",@"source_total",
                            file.shortPath,@"source_path",
                            file.name,@"source_file",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    downloadOperation = [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi/%@",
                                                                    filename]]
                                parameters:params
                                   success:successBlock
                                   failure:failureBlock];
    
    downloadOperation.outputStream = [NSOutputStream outputStreamToFileAtPath:localName append:NO];
    
    __block long long lastNotifiedProgress = 0;
    [downloadOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
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
    
    [downloadOperation setCompletionBlockWithSuccess:successBlock
                                             failure:failureBlock];
}

- (void)cancelDownloadTask
{
    // Cancel request
    [downloadOperation cancel];
    
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
}

#pragma mark - upload management

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
    __weak typeof(self) weakSelf = self;
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        NSInteger status = [[JSON objectForKey:@"status"] integerValue];
        switch (status)
        {
            case QNAP_STATUS_OK:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:YES],@"success",
                                                     nil]];
                });
                break;
            }
            case QNAP_STATUS_PERMISSION_DENIED:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     @"Permission denied",@"error",
                                                     nil]];
                });
                break;
            }
            case QNAP_STATUS_QUOTA_EXCEEDED:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     @"Quota limit exceeded",@"error",
                                                     nil]];
                });
                break;
            }
            default:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     [NSString stringWithFormat:@"Unknown error %ld",(long)status],@"error",
                                                     nil]];
                });
                break;
            }
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (error.code != kCFURLErrorCancelled)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [error description],@"error",
                                                 nil]];
            });
        }
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            file.name,@"Filename",
                            nil];
    
    void (^bodyConstructorBlock)(id <AFMultipartFormData> formData) =^(id <AFMultipartFormData> formData) {
        NSError *error = nil;
        [formData appendPartWithFileURL:[NSURL fileURLWithPath:file.fullPath] name:@"file" error:&error];
        if (error)
        {
            NSLog(@"error %@",[error description]);
        }
    };
    
    self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
    // text/html is content types returned by QNAP servers
    [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:QNAP_ACCEPTABLE_CONTENT_TYPES,nil]];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    uploadOperation = [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"cgi-bin/filemanager/utilRequest.cgi?func=upload&sid=%@&dest_path=%@&overwrite=%d",
                                                                  sID,
                                                                  [destFolder.path encodeString:NSUTF8StringEncoding],
                                                                  overwrite?0:1]]
                              parameters:params
               constructingBodyWithBlock:bodyConstructorBlock
                                 success:successBlock
                                 failure:failureBlock];
    
    __block long long lastNotifiedProgress = 0;
    [uploadOperation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        // send a notification every 0,5% of progress (to limit the impact on performances)
        if ((totalBytesWritten >= lastNotifiedProgress + totalBytesExpectedToWrite/200) || (totalBytesWritten == totalBytesExpectedToWrite))
        {
            lastNotifiedProgress = totalBytesWritten;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate CMUploadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithLongLong:totalBytesWritten],@"uploadedBytes",
                                                     file.fileSizeNumber,@"totalBytes",
                                                     [NSNumber numberWithFloat:(float)((float)totalBytesWritten/(float)([file.fileSizeNumber longLongValue]))],@"progress",
                                                     nil]];
            });
        }
    }];
}

- (void)cancelUploadTask
{
    // Cancel request
    [uploadOperation cancel];
    
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
}

#pragma mark - url management

#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file
{
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.url = [NSURL URLWithString:[[self createUrl] stringByAppendingFormat:@"/cgi-bin/filemanager/utilRequest.cgi/%@?isfolder=0&func=download&sid=%@&source_total=1&source_path=%@&source_file=%@",
                                                  [file.name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                                                  sID,
                                                  [file.shortPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                                                  [file.name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    networkConnection.urlType = URLTYPE_HTTP;
    
  	return networkConnection;
}
#endif

#pragma mark - supported features

- (NSInteger)supportedFeaturesAtPath:(NSString *)path
{
    NSInteger features = CMSupportedFeaturesNone;
    if (![path isEqualToString:@"/"])
    {
        features = CMSupportedFeaturesMaskFileDelete      |
                   CMSupportedFeaturesMaskFolderDelete    |
                   CMSupportedFeaturesMaskFolderCreate    |
                   CMSupportedFeaturesMaskFileRename      |
                   CMSupportedFeaturesMaskFolderRename    |
                   CMSupportedFeaturesMaskFileMove        |
                   CMSupportedFeaturesMaskMoveCancel      |
                   CMSupportedFeaturesMaskFolderMove      |
                   CMSupportedFeaturesMaskFileCopy        |
                   CMSupportedFeaturesMaskFolderCopy      |
                   CMSupportedFeaturesMaskCopyCancel      |
                   CMSupportedFeaturesMaskExtract         |
                   CMSupportedFeaturesMaskExtractCancel   |
                   CMSupportedFeaturesMaskSearch          |
                   CMSupportedFeaturesMaskFileDownload    |
                   CMSupportedFeaturesMaskDownloadCancel  |
                   CMSupportedFeaturesMaskFileUpload      |
                   CMSupportedFeaturesMaskUploadCancel    |
                   CMSupportedFeaturesMaskEject           |
                   CMSupportedFeaturesMaskVideoSeek       |
                   CMSupportedFeaturesMaskAirPlay         |
                   CMSupportedFeaturesMaskGoogleCast;
        
        // File compression is available for firmware >= 4.0
        if (([self.version compare:QNAP_FIRMWARE_4_0 options:NSNumericSearch] != NSOrderedAscending))
        {
            features |= CMSupportedFeaturesMaskCompress   |
                        CMSupportedFeaturesMaskCompressCancel |
                        CMSupportedFeaturesMaskFileShare       |
                        CMSupportedFeaturesMaskFolderShare;
        }
        
        if ((!self.userAccount.boolSSL) || (!self.userAccount.acceptUntrustedCertificate))
        {
            // For now I didn't find a way to use internal QT player to play
            // media on a server with untrusted certificate !
            features |= CMSupportedFeaturesMaskQTPlayer |
                        CMSupportedFeaturesMaskVLCPlayer;
        }
    }
    else
    {
        features |= CMSupportedFeaturesMaskEject;
    }

    return features;
}

#ifndef APP_EXTENSION
- (NSInteger)supportedArchiveType
{
    NSInteger supportedTypes = CMSupportedArchivesMaskZip |
                               CMSupportedArchivesMask7z ;
    return supportedTypes;
}

- (NSInteger)supportedSharingFeatures
{
    NSInteger supportedFeatures = CMSupportedSharingMaskPassword |
    CMSupportedSharingMaskValidityPeriod;
    return supportedFeatures;
}
#endif

#pragma mark - Private methods

- (void)firmwareVersion
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id response) {
        NSDictionary *xml = [NSDictionary dictionaryWithXMLData:response];
        self.version = [xml valueForKeyPath:@"firmware.version"];
        
        serverModel = [xml valueForKeyPath:@"model.modelName"];
        serverFirmware = [NSString stringWithFormat:@"%@-%@", self.version, [xml valueForKeyPath:@"firmware.build"]];
        serverHostname = [xml valueForKeyPath:@"hostname"];
        
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    nil]];
        });
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    nil]];
        });

    };
    
    self.manager.responseSerializer = [AFHTTPResponseSerializer serializer];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:@"cgi-bin/sysinfoReq.cgi"]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}

// Return true if this connection manager can extract this file type
- (BOOL)isCompressed:(NSString *)type
{
    BOOL supportedArchiveType = NO;
    if (([[type lowercaseString] isEqualToString:@"7z"]) ||
        ([[type lowercaseString] isEqualToString:@"gzip"]) ||
        ([[type lowercaseString] isEqualToString:@"gz"]) ||
        ([[type lowercaseString] isEqualToString:@"zip"]) ||
        ([[type lowercaseString] isEqualToString:@"bzip2"]) ||
        ([[type lowercaseString] isEqualToString:@"bz2"]) ||
        ([[type lowercaseString] isEqualToString:@"tar"]) ||
        ([[type lowercaseString] isEqualToString:@"rar"]) ||
        ([[type lowercaseString] isEqualToString:@"tgz"]))
    {
        supportedArchiveType = YES;
    }
    return supportedArchiveType;
}

@end
