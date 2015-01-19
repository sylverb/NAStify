//
//  CMSynology.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//
//  TODO : Use timer to handle automatic reconnection
//

#import "CMSynology.h"
#import "SBNetworkActivityIndicator.h"
#import "NSStringAdditions.h"
#import "SSKeychain.h"

@interface CMSynology (Private)
- (NSString *)createUrlWithPath:(NSString *)path;
- (NSString *)createUrl;
- (void)serverData;
- (void)serverModelData;
- (void)oldServerData;
- (void)dsmVersion;
#ifndef APP_EXTENSION
- (void)ejectableList;
- (void)deleteProgressV4_3;
- (void)deleteProgressV3_X;
- (void)deleteProgressV2_X;
- (void)cancelDeleteTaskV4_3;
- (void)cancelDeleteTaskV3_X;
- (void)copyProgress;
- (void)copyProgressV4_3;
- (void)copyProgressV3_X;
- (void)copyProgressV2_X;
- (void)cancelCopyTaskV4_3;
- (void)cancelCopyTaskV3_X;
- (void)moveProgress;
- (void)moveProgressV4_3;
- (void)moveProgressV3_X;
- (void)moveProgressV2_X;
- (void)cancelMoveTaskV4_3;
- (void)cancelMoveTaskV3_X;
- (void)searchProgress;
- (void)extractProgress;
- (void)extractProgress2;
- (void)compressProgress;
- (void)compressProgress2;
#endif
- (BOOL)isCompressed:(NSString *)type;
- (NSString *)escapeSynoString:(NSString *)inputString;
@end

#define ERROR_NO_PERMISSION         105 // The logged in session does not have permission
#define ERROR_SESSION_TIMEOUT       106 // Session timeout
#define ERROR_SESSION_INTERRUPTED   107 // Session interrupted by duplicate login

#define ERROR_FS_NO_PERMISSION      409 // No permission for this place

#define HandleServerDisconnection() \
{ \
    NSLog(@"JSON %@",JSON); \
    if (([JSON isKindOfClass:[NSDictionary class]]) && ([[JSON objectForKey:@"success"] boolValue] == NO)) \
    { \
        if ([JSON objectForKey:@"errno"]) \
        { \
            if ([[[JSON objectForKey:@"errno"] objectForKey:@"key"] isEqualToString:@"error_interrupt"]) \
            { \
                dispatch_async(dispatch_get_main_queue(), ^{ \
                    [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys: \
                                            [NSNumber numberWithBool:NO],@"success", \
                                            @"Disconnected",@"error", \
                                            nil]]; \
                }); \
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
                return; \
            } \
        } \
    else if ([JSON objectForKey:@"error"]) \
        { \
            NSInteger error = 0; \
            if ([[JSON objectForKey:@"error"] isKindOfClass:[NSDictionary class]]) \
            { \
                error = [[[JSON objectForKey:@"error"] objectForKey:@"code"] integerValue]; \
            } \
            else \
            { \
                error = [[JSON objectForKey:@"error"] integerValue]; \
            } \
            switch (error) \
                { \
                    case ERROR_NO_PERMISSION: \
                    case ERROR_SESSION_TIMEOUT: \
                        { \
                            dispatch_async(dispatch_get_main_queue(), ^{ \
                                [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys: \
                                                        [NSNumber numberWithBool:NO],@"success", \
                                                        @"Connection timeout",@"error", \
                                                        nil]]; \
                            }); \
                            break; \
                        } \
                    case ERROR_SESSION_INTERRUPTED: \
                        { \
                            dispatch_async(dispatch_get_main_queue(), ^{ \
                                [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys: \
                                                        [NSNumber numberWithBool:NO],@"success", \
                                                        @"Disconnected",@"error", \
                                                        nil]]; \
                            }); \
                            break; \
                        } \
                    default: \
                        break; \
                } \
            } \
        } \
    }

@implementation CMSynology

- (id)init
{
    self = [super init];
    if (self)
    {
        self.manager = [AFHTTPRequestOperationManager manager];
        self.manager.requestSerializer = [AFHTTPRequestSerializer serializer];
        self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
        // text/html and text/plain are content types returned by Synology's servers
        [self.manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:@"text/html", @"text/plain", nil]];
        
        timeoutDuration = 10 * 60; // Default to 10 minutes
        protocolVersion = -1;
        lastRequestDate = [NSDate date];
    }
    return self;
}

- (NSString *)createUrl
{
    NSString * url;
    if (quickConnectServer)
    {
        url = quickConnectServerExternal;
    }
    else
    {
        url = self.userAccount.server;
    }
    if (self.userAccount.boolSSL)
    {
        url = [NSString stringWithFormat:@"https://%@", url];
    }
    else
    {
        url = [NSString stringWithFormat:@"http://%@", url];
    }
    NSString *port;
    if (self.userAccount.port && ([self.userAccount.port length] != 0))
    {
        port = self.userAccount.port;
    }
    else
    {
        port = quickConnectPortExternal;
    }
    
    if ((port == nil) || ([port length] == 0))
    {
        if (self.userAccount.boolSSL)
        {
            port = @"5001";
        }
        else
        {
            port = @"5000";
        }
    }
    
    NSString * req = [NSString stringWithFormat:@"%@:%@", url, port];
    return req;
}

- (NSString *)createUrlWithPath:(NSString *)path
{
    return [NSString stringWithFormat:@"%@/%@", [self createUrl], path];
}

- (NSString *)createUrlWithCredentials
{
    NSString * url;
    if (quickConnectServer)
    {
        url = quickConnectServerExternal;
    }
    else
    {
        url = self.userAccount.server;
    }
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
    
    NSString *port;
    if (self.userAccount.port && ([self.userAccount.port length] != 0))
    {
        port = self.userAccount.port;
    }
    else
    {
        port = quickConnectPortExternal;
    }
    
    if ((port == nil) || ([port length] == 0))
    {
        if (self.userAccount.boolSSL)
        {
            port = @"5001";
        }
        else
        {
            port = @"5000";
        }
    }
    
    NSString * req = [NSString stringWithFormat:@"%@:%@", url, port];
    return req;
}

#pragma mark - Server Info

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           [NSString stringWithFormat:NSLocalizedString(@"Server Model : Synology %@",nil), serverModel],
                           [NSString stringWithFormat:NSLocalizedString(@"Firmware : %@", nil), serverFirmwareVersion],
                           [NSString stringWithFormat:NSLocalizedString(@"Serial Number : %@", nil), serverSerial],
                           [NSString stringWithFormat:NSLocalizedString(@"CPU : %@", nil), serverCPUInfo],
                           [NSString stringWithFormat:NSLocalizedString(@"RAM : %d MB", nil), serverRAMSize],
                           nil];
    return serverInfo;
}

#pragma mark - Quickconnect handling

- (void)getServerFromQuickconnect
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        quickConnectRequestsLeft --;
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        if ([[JSON objectForKey:@"errno"] intValue] == 0)
        {
            quickConnectServer = [[[[JSON objectForKey:@"server"] objectForKey:@"interface"] objectAtIndex:0] objectForKey:@"ip"];
            quickConnectServerExternal = [[[JSON objectForKey:@"server"] objectForKey:@"external"] objectForKey:@"ip"];
            quickConnectPort = [[[JSON objectForKey:@"service"] objectForKey:@"port"] stringValue];
            quickConnectPortExternal = [[[JSON objectForKey:@"service"] objectForKey:@"ext_port"] stringValue];
            if ([quickConnectPortExternal intValue] == 0)
            {
                quickConnectPortExternal = quickConnectPort;
            }
            
            [self loginRequest];
        }
        else if ([[JSON objectForKey:@"errno"] intValue] != 4)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        @"Unable to get QuickConnect info from server",@"error",
                                        nil]];
            });
        }
        else if ((quickConnectRequestsLeft == 0) && (quickConnectServer == nil))
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        @"Invalid QuickConnect ID",@"error",
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
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithInt:1],@"version",
                            @"get_server_info",@"command",
                            @"dsm_portal",@"id",
                            self.userAccount.server,@"serverID",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    quickConnectRequestsLeft = 3;
    
    self.manager.securityPolicy.allowInvalidCertificates = self.userAccount.acceptUntrustedCertificate;
    self.manager.requestSerializer = [AFJSONRequestSerializer serializer];

    [self.manager POST:[NSString stringWithFormat:@"http://%@.quickconnect.to/ukc/Serv.php",self.userAccount.server]
            parameters:params
               success:successBlock
               failure:failureBlock];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

    [self.manager POST:[NSString stringWithFormat:@"http://%@.quickconnect.to/usc/Serv.php",self.userAccount.server]
            parameters:params
               success:successBlock
               failure:failureBlock];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

    [self.manager POST:[NSString stringWithFormat:@"http://%@.quickconnect.to/twc/Serv.php",self.userAccount.server]
            parameters:params
               success:successBlock
               failure:failureBlock];

    lastRequestDate = [NSDate date];
}

#pragma mark - login/logout management

- (BOOL)login
{
    if ([self.userAccount.server rangeOfString:@"."].location != NSNotFound)
    {
        [self loginRequest];
    }
    else
    {
        [self getServerFromQuickconnect];
    }
    return YES;
}

- (void)loginRequest
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        if ([[JSON objectForKey:@"result"] isEqualToString:@"success"])
        {
            if ([JSON objectForKey:@"SynoToken"])
            {
                synoToken = [JSON objectForKey:@"SynoToken"];
            }
            [self serverData];
            [self serverModelData];
        }
        else if ([[JSON objectForKey:@"request_otp"] boolValue])
        {
            // Request 2-Factor authentication One Time Password
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMRequestOTP:nil];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        [JSON objectForKey:@"reason"],@"error",
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
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            self.userAccount.userName,@"username",
                            [SSKeychain passwordForService:self.userAccount.uuid account:@"password"],@"passwd",
                            @"1",@"service_type",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    self.manager.securityPolicy.allowInvalidCertificates = self.userAccount.acceptUntrustedCertificate;
    self.manager.requestSerializer = [AFHTTPRequestSerializer serializer];

    [self.manager POST:[self createUrlWithPath:@"webman/modules/login.cgi?enable_syno_token=yes"]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - OTP management

- (void)sendOTP:(NSString *)otp;
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();

        if ([[JSON objectForKey:@"result"] isEqualToString:@"success"])
        {
            if ([JSON objectForKey:@"SynoToken"])
            {
                synoToken = [JSON objectForKey:@"SynoToken"];
            }
            [self serverData];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        [JSON objectForKey:@"reason"],@"error",
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
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            self.userAccount.userName,@"username",
                            [SSKeychain passwordForService:self.userAccount.uuid account:@"password"],@"passwd",
                            otp,@"OTPcode",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"webman/modules/login.cgi?enable_syno_token=yes"]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (BOOL)logout
{
    void (^successBlock)(AFHTTPRequestOperation *,id) = ^(AFHTTPRequestOperation *operation, id responseObject) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        synoToken = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogout:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    nil]];
        });

        NSLog(@"logout");
    };

    void (^failureBlock)(AFHTTPRequestOperation *, NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        synoToken = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogout:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO],@"success",
                                    [error description],@"error",
                                    nil]];
        });
    };

#ifndef APP_EXTENSION
    deleteTaskID = nil;
    copyTaskID = nil;
    moveTaskID = nil;
    extractTaskID = nil;
    compressTaskID = nil;
    searchTaskID = nil;
#endif
    
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        urlPath = @"webman/logout.cgi";
    }
    else
    {
        urlPath = @"webman/modules/logout.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:urlPath]
            parameters:nil
               success:successBlock
               failure:failureBlock];
    
    return YES;
}

#ifndef APP_EXTENSION
- (void)sendOTPEmergencyCode
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue] == TRUE)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMAction:[NSDictionary dictionaryWithObjectsAndKeys:
                                         NSLocalizedString(@"Information",nil),@"title",
                                         NSLocalizedString(@"An emergency code will be sent to you, please check and reconnect",nil),@"message",
                                         [NSNumber numberWithInteger:BROWSER_ACTION_QUIT_SERVER],@"action",
                                        nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMAction:[NSDictionary dictionaryWithObjectsAndKeys:
                                         NSLocalizedString(@"Error",nil),@"title",
                                         NSLocalizedString(@"Emergency code request failed",nil),@"message",
                                         [NSNumber numberWithInteger:BROWSER_ACTION_QUIT_SERVER],@"action",
                                         nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSLog(@"%@", error);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMAction:[NSDictionary dictionaryWithObjectsAndKeys:
                                     NSLocalizedString(@"Error",nil),@"title",
                                     NSLocalizedString(@"Emergency code request failed",nil),@"message",
                                     [NSNumber numberWithInteger:BROWSER_ACTION_QUIT_SERVER],@"action",
                                     nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            self.userAccount.userName,@"username",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"webman/mail_otp.cgi"]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}
#endif

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self listForPathV4_3:folder];
    }
    else
    {
        [self listForPathV3_X:folder];
    }
}

- (void)listForPathV4_3:(FileItem *)folder
{
	if ([folder.path isEqualToString:@"/"])
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"success"] boolValue] == YES)
            {
#ifndef APP_EXTENSION
                // get ejectable list
                [self ejectableList];
#endif
                
                NSMutableArray *filesOutputArray = [NSMutableArray array];
                for (NSDictionary *file in [[JSON objectForKey:@"data"] objectForKey:@"shares"])
                {
                    NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithBool:YES],@"isdir",
                                              [file objectForKey:@"name"],@"filename",
                                              [file objectForKey:@"path"],@"path",
                                              [NSNumber numberWithBool:NO],@"iscompressed",
                                              [NSNumber numberWithBool:NO],@"writeaccess",
                                              nil];
                    
                    [filesOutputArray addObject:dictItem];
                }
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:YES],@"success",
                                            folder.path,@"path",
                                            filesOutputArray,@"filesList",
                                            nil]];
            }
            else
            {
                NSString *error = [NSString stringWithFormat:@"Error code %@",[[JSON objectForKey:@"error"] objectForKey:@"code"]];
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            folder.path,@"path",
                                            error,@"error",
                                            nil]];
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            NSLog(@"%@", error);
        };
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_share.cgi?filetype=dir&sort_by=name&additional=real_path%%2Cowner%%2Ctime%%2Cperm%%2Cmount_point_type%%2Csync_share%%2Cvolume_status&node=fm_root&api=SYNO.FileStation.List&method=list_share&version=1&SynoToken=%@",synoToken]]
               parameters:nil
                  success:successBlock
                  failure:failureBlock];
        
        lastRequestDate = [NSDate date];
	}
    else
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"success"] boolValue] == YES)
            {
                NSMutableArray *filesOutputArray = [NSMutableArray array];
                for (NSDictionary *file in [[JSON objectForKey:@"data"] objectForKey:@"files"])
                {
                    NSNumber *size = [NSNumber numberWithInt:0];
                    if ([[file objectForKey:@"additional"] objectForKey:@"size"])
                    {
                        size = [NSNumber numberWithLongLong:[[[file objectForKey:@"additional"] objectForKey:@"size"] longLongValue]];
                    }
                    
                    bool iscompressed = [self isCompressed:[[file objectForKey:@"additional"] objectForKey:@"type"]];
                    
                    NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [file objectForKey:@"isdir"],@"isdir",
                                              [file objectForKey:@"name"],@"filename",
                                              [file objectForKey:@"path"],@"path",
                                              size,@"filesizenumber",
                                              [[[file objectForKey:@"additional"] objectForKey:@"owner"] objectForKey:@"group"],@"group",
                                              [[[file objectForKey:@"additional"] objectForKey:@"owner"] objectForKey:@"user"],@"owner",
                                              iscompressed?@"1":@"0",@"iscompressed", // Supports .zip, .tar, .gz, .tgz, .rar, .7z, .iso (ISO 9660 + joliet)
                                              [[[[file objectForKey:@"additional"] objectForKey:@"perm"] objectForKey:@"acl"] objectForKey:@"del"],@"writeaccess",
                                              [[[file objectForKey:@"additional"] objectForKey:@"time"] objectForKey:@"mtime"],@"date",
                                              [[file objectForKey:@"additional"] objectForKey:@"type"],@"type",
                                              nil];
                    
                    [filesOutputArray addObject:dictItem];
                }
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:YES],@"success",
                                            folder.path,@"path",
                                            filesOutputArray,@"filesList",
                                            nil]];
            }
            else
            {
                NSString *error = [NSString stringWithFormat:@"Error code %@",[[JSON objectForKey:@"error"] objectForKey:@"code"]];
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            folder.path,@"path",
                                            error,@"error",
                                            nil]];
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            NSLog(@"%@", error);
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"0",@"offset",
                                @"5000",@"limit",
                                @"name",@"sort_by", // filename,mtime,filesize,type
                                @"ASC",@"sort_direction", // DESC,ASC
                                @"list",@"action",
                                @"real_path,size,owner,time,perm,type,mount_point_type",@"additional",
                                @"all",@"filetype",
                                [self escapeSynoString:folder.path],@"folder_path",
                                @"SYNO.FileStation.List",@"api",
                                @"list",@"method",
                                @"1",@"version",
                                nil];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_share.cgi?SynoToken=%@",synoToken]]
               parameters:params
                  success:successBlock
                  failure:failureBlock];
        
        lastRequestDate = [NSDate date];
	}
}

- (void)listForPathV3_X:(FileItem *)folder
{
	if ([folder.path isEqualToString:@"/"])
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
#ifndef APP_EXTENSION
            // get ejectable list
            [self ejectableList];
#endif

            NSMutableArray *filesOutputArray = [NSMutableArray array];
            if ([JSON isKindOfClass:[NSArray class]])
            {
                for (NSDictionary *file in JSON)
                {
                    NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithBool:YES],@"isdir",
                                              [file objectForKey:@"text"],@"filename",
                                              [file objectForKey:@"path"],@"path",
                                              [NSNumber numberWithBool:NO],@"iscompressed",
                                              [NSNumber numberWithBool:NO],@"writeaccess",
                                              nil];
                    
                    [filesOutputArray addObject:dictItem];
                }
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:YES],@"success",
                                            folder.path,@"path",
                                            filesOutputArray,@"filesList",
                                            nil]];
            }
            else
            {
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            folder.path,@"path",
                                            nil]];
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            NSLog(@"%@", error);
        };
        
        NSString *urlPath = nil;
        if (dsmVersion >= SYNOLOGY_DSM_3_0)
        {
            urlPath = @"/webman/modules/FileBrowser/webfm/webUI/file_share.cgi?action=getshares&node=fm_root";
        }
        else
        {
            urlPath = @"/webfm/webUI/file_share.cgi?action=getshares&node=fm_root";
        }
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager GET:[self createUrlWithPath:urlPath]
               parameters:nil
                  success:successBlock
                  failure:failureBlock];
        
        lastRequestDate = [NSDate date];
	}
    else
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            NSMutableArray *filesOutputArray = [NSMutableArray array];
            for (NSDictionary *file in [JSON objectForKey:@"items"])
            {
                NSNumber *size = [NSNumber numberWithInt:0];
                if ([file objectForKey:@"size"])
                {
                    size = [NSNumber numberWithLongLong:[[file objectForKey:@"size"] longLongValue]];
                }
                else if ([file objectForKey:@"filesize"])
                {
                    // This is needed to handle old firmwares
                    size = [[file objectForKey:@"filesize"] valueForStringBytes];
                }
                
                NSNumber *iscompressed = [NSNumber numberWithBool:[[file objectForKey:@"is_compressed"] boolValue]];
                
                NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [file objectForKey:@"isdir"],@"isdir",
                                          [file objectForKey:@"filename"],@"filename",
                                          [file objectForKey:@"path"],@"path",
                                          size,@"filesizenumber",
                                          [file objectForKey:@"group"],@"group",
                                          [file objectForKey:@"owner"],@"owner",
                                          iscompressed,@"iscompressed", // Supports .zip, .tar, .gz, .tgz, .rar, .7z, .iso (ISO 9660 + joliet)
                                          [NSNumber numberWithBool:YES],@"writeaccess",
                                          [file objectForKey:@"mt"],@"date",
                                          [file objectForKey:@"type"],@"type",
                                          nil];
                
                [filesOutputArray addObject:dictItem];
            }
            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES],@"success",
                                        folder.path,@"path",
                                        filesOutputArray,@"filesList",
                                        nil]];
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            NSLog(@"%@", error);
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"0",@"start",
                                @"5000",@"limit",
                                @"filename",@"sort", // filename,mt,filesize,type
                                @"ASC",@"dir", // DESC,ASC
                                @"getfiles",@"action",
                                @"all",@"need",
                                folder.path,@"target",
                                nil];
        
        NSString *urlPath = nil;
        if (dsmVersion >= SYNOLOGY_DSM_3_0)
        {
            urlPath = @"webman/modules/FileBrowser/webfm/webUI/webfm.cgi";
        }
        else
        {
            urlPath = @"webfm/webUI/webfm.cgi";
        }
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:urlPath]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
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
            
            if ([[JSON objectForKey:@"success"] boolValue])
            {
                NSNumber *total = [NSNumber numberWithInt:0];
                NSNumber *free = [[JSON objectForKey:@"free"] valueForStringBytes];
                
                if ([JSON objectForKey:@"total"])
                {
                    total = [[JSON objectForKey:@"total"] valueForStringBytes];
                }
                else
                {
                    long long freeLong = [free longLongValue];
                    long long usedLong = [[[JSON objectForKey:@"used"] valueForStringBytes] longLongValue];
                    long long totalLong = freeLong + usedLong;
                    total = [NSNumber numberWithLongLong:totalLong];
                }
                
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
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                folder.path,@"cwd",
                                @"getfs",@"action",
                                nil];

        NSString *path = nil;
        if (dsmVersion >= SYNOLOGY_DSM_3_0)
        {
            if (synoToken)
            {
                path = [NSString stringWithFormat:@"webman/modules/FileBrowser/webfm/webUI/webfm.cgi?SynoToken=%@",synoToken];
            }
            else
            {
                path = @"webman/modules/FileBrowser/webfm/webUI/webfm.cgi";
            }
        }
        else
        {
            path = @"webfm/webUI/webfm.cgi";
        }
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:path]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

#pragma mark - Folder creation management

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self createFolderV4_3:folderName atPath:folder];
    }
    else
    {
        [self createFolderV3_X:folderName atPath:folder];
    }

}

- (void)createFolderV4_3:(NSString *)folderName atPath:(FileItem *)folder;
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
        else
        {
            NSString *error = [NSString stringWithFormat:@"Error code %@",[[JSON objectForKey:@"error"] objectForKey:@"code"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               error,@"error",
                                               nil]];
            });
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
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            folder.path,@"folder_path",
                            folderName,@"name",
                            @"false",@"force_parent",
                            @"SYNO.FileStation.CreateFolder",@"api",
                            @"create",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_crtfdr.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)createFolderV3_X:(NSString *)folderName atPath:(FileItem *)folder;
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
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
                                               [[JSON objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                               nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [error localizedDescription],@"error",
                                           nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"createfolder",@"action",
                            folderName,@"files",
                            folder.path,@"dest",
                            nil];
    
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_crtfdr.cgi";
    }
    else
    {
        urlPath = @"webfm/webUI/file_crtfdr.cgi";
    }

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - delete management

#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self deleteFilesV4_3:files];
    }
    else
    {
        [self deleteFilesV3_X:files];
    }
}

- (void)deleteProgress
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self deleteProgressV4_3];
    }
    else if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        [self deleteProgressV3_X];
    }
    else
    {
        [self deleteProgressV2_X];
    }
}

- (void)cancelDeleteTask
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self cancelDeleteTaskV4_3];
    }
    else
    {
        [self cancelDeleteTaskV3_X];
    }
}

#pragma mark - delete management DSM v4.3

- (void)deleteFilesV4_3:(NSArray *)files
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            deleteTaskID = [[JSON objectForKey:@"data"] objectForKey:@"taskid"];
            [self performSelector:@selector(deleteProgress) withObject:nil afterDelay:0.2];
        }
        else
        {
            NSString *error = [NSString stringWithFormat:@"Error code %@",[[JSON objectForKey:@"error"] objectForKey:@"code"]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 error,@"error",
                                                 nil]];
            });
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
    
    NSMutableString *pathString = [NSMutableString string];
    
    for (FileItem *file in files)
    {
        [pathString appendFormat:@"%@",[self escapeSynoString:file.fullPath]];
        if (file != [files lastObject])
        {
            [pathString appendString:@","];
        }
    }
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            pathString,@"path",
                            @"true",@"accurate_progress",
                            @"SYNO.FileStation.Delete",@"api",
                            @"start",@"method",
                            @"1",@"version",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_delete.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)deleteProgressV4_3
{
    if (deleteTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"success"] boolValue])
            {
                bool deleteRunning = ![[[JSON objectForKey:@"data"] objectForKey:@"finished"] boolValue];
                float progress = [[[JSON objectForKey:@"data"] objectForKey:@"progress"] floatValue];
                if (progress == -1.0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         @"Unknown error",@"error",
                                                         nil]];
                    });
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMDeleteProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithFloat:progress],@"progress",
                                                         nil]];
                    });
                }
                if (deleteRunning)
                {
                    // Update progress
                    [self performSelector:@selector(deleteProgress)
                               withObject:nil
                               afterDelay:2];
                }
                else{
                    // Deletion is now finished
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:YES],@"success",
                                                         nil]];
                    });
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     @"Unknown error",@"error",
                                                     nil]];
                });
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [error localizedDescription],@"error",
                                                 nil]];
            });
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                deleteTaskID,@"taskid",
                                @"SYNO.FileStation.Delete",@"api",
                                @"status",@"method",
                                @"1",@"version",
                                nil];

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_delete.cgi?SynoToken=%@",synoToken]]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelDeleteTaskV4_3
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        deleteTaskID = nil;
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        deleteTaskID = nil;
        
        NSLog(@"%@", error);
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            deleteTaskID,@"taskid",
                            @"SYNO.FileStation.Delete",@"api",
                            @"stop",@"method",
                            @"1",@"version",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_delete.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - delete management DSM v3.X

- (void)deleteFilesV3_X:(NSArray *)files
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            if (dsmVersion >= SYNOLOGY_DSM_3_0)
            {
                deleteTaskID = [JSON objectForKey:@"taskid"];
            }
            else if ([JSON objectForKey:@"pid"])
            {
                deleteTaskID = [JSON objectForKey:@"pid"];
            }
            [self performSelector:@selector(deleteProgress) withObject:nil afterDelay:0.2];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             [error localizedDescription],@"error",
                                             nil]];
        });
    };
    
    NSMutableString *filesString = [NSMutableString string];
    NSMutableString *curDirsString = [NSMutableString string];
    
    for (FileItem *file in files)
    {
        [filesString appendFormat:@"%@",file.fullPath];
        [curDirsString appendFormat:@"%@",file.shortPath];
        if (file != [files lastObject])
        {
            [filesString appendString:@"_SYNOFM_"];
            [curDirsString appendString:@"_SYNOFM_"];
        }
    }
    
    NSDictionary *params = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_1)
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"delete",@"action",
                  filesString,@"files",
                  curDirsString,@"curDirs",
                  nil];
    }
    else
    {
        NSString *path = ((FileItem *)[files objectAtIndex:0]).shortPath;
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"delete",@"action",
                  filesString,@"files",
                  path,@"curDir",
                  nil];
    }
    
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_delete.cgi";
    }
    else
    {
        urlPath = @"webfm/webUI/file_delete.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)deleteProgressV3_X
{
    if (deleteTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[[JSON objectForKey:@"data"] objectForKey:@"result"] isEqualToString:@"fail"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     [[[JSON objectForKey:@"data"] objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                                     nil]];
                });
            }
            else
            {
                if ([[JSON objectForKey:@"success"] boolValue])
                {
                    bool deleteRunning = ![[JSON objectForKey:@"finished"] boolValue];
                    float progress = [[JSON objectForKey:@"progress"] floatValue];
                    if (progress == -1.0)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithBool:NO],@"success",
                                                             @"Unknown error",@"error",
                                                             nil]];
                        });
                    }
                    else
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMDeleteProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithFloat:progress],@"progress",
                                                             nil]];
                        });
                    }
                    if (deleteRunning)
                    {
                        // Update progress
                        [self performSelector:@selector(deleteProgress)
                                   withObject:nil
                                   afterDelay:2];
                    }
                    else
                    {
                        // Deletion is now finished
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithBool:YES],@"success",
                                                             nil]];
                        });
                    }
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         @"Unknown error",@"error",
                                                         nil]];
                    });
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [error localizedDescription],@"error",
                                                 nil]];
            });
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"readprogress",@"action",
                                deleteTaskID,@"taskid",
                                nil];

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:@"webman/modules/FileBrowser/webfm/webUI/file_delete.cgi"]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelDeleteTaskV3_X
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        deleteTaskID = nil;
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        deleteTaskID = nil;
    };
    
    NSDictionary *params = nil;
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"cancelprogress",@"action",
                  deleteTaskID,@"taskid",
                  nil];
        
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_delete.cgi";
    }
    else
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"canceldelete",@"action",
                  @"webUI/file_delete.cgi",@"url",
                  copyTaskID,@"pid",
                  nil];
        
        urlPath = @"webfm/webUI/file_delete.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - delete management DSM v2.X

- (void)deleteProgressV2_X
{
    if (deleteTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"result"] isEqualToString:@"fail"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     [[JSON objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                                     nil]];
                });
            }
            else
            {
                if ([[JSON objectForKey:@"success"] boolValue])
                {
                    bool deleteRunning = [[JSON objectForKey:@"running"] boolValue];
                    float progress = [[JSON objectForKey:@"progress"] floatValue];
                    if (progress == -1.0)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithBool:NO],@"success",
                                                             @"Unknown error",@"error",
                                                             nil]];
                        });
                    }
                    else
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMDeleteProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithFloat:progress],@"progress",
                                                             nil]];
                        });
                    }
                    if (deleteRunning)
                    {
                        // Update progress
                        [self performSelector:@selector(deleteProgress)
                                   withObject:nil
                                   afterDelay:2];
                    }
                    else
                    {
                        // Copy is now finished
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSNumber numberWithBool:YES],@"success",
                                                             nil]];
                        });
                    }
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         @"Unknown error",@"error",
                                                         nil]];
                    });
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [error localizedDescription],@"error",
                                                 nil]];
            });
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"readdeleteprogress",@"action",
                                @"webUI/file_delete.cgi",@"url",
                                deleteTaskID,@"pid",
                                nil];

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:@"webfm/webUI/file_delete.cgi"]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}
#endif

#pragma mark - copy management

#ifndef APP_EXTENSION
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self copyFilesV4_3:files toPath:destFolder andOverwrite:overwrite];
    }
    else
    {
        [self copyFilesV3_X:files toPath:destFolder andOverwrite:overwrite];
    }
}

- (void)copyProgress
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self copyProgressV4_3];
    }
    else if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        [self copyProgressV3_X];
    }
    else
    {
        [self copyProgressV2_X];
    }
}

- (void)cancelCopyTask
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self cancelCopyTaskV4_3];
    }
    else
    {
        [self cancelCopyTaskV3_X];
    }
}

#pragma mark - copy management DSM v4.3

- (void)copyFilesV4_3:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            copyTaskID = [[JSON objectForKey:@"data"] objectForKey:@"taskid"];
            [self performSelector:@selector(copyProgress) withObject:nil afterDelay:0.2];
        }
        else
        {
            NSString *error = [NSString stringWithFormat:@"Error code %@",[[JSON objectForKey:@"error"] objectForKey:@"code"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               error,@"error",
                                               nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [error localizedDescription],@"error",
                                           nil]];
        });
    };
    
    NSMutableString *pathString = [NSMutableString string];
    
    for (FileItem *file in files)
    {
        [pathString appendFormat:@"%@",[self escapeSynoString:file.fullPath]];
        if (file != [files lastObject])
        {
            [pathString appendString:@","];
        }
    }
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            overwrite?@"true":@"false",@"overwrite",
                            [self escapeSynoString:destFolder.path],@"dest_folder_path",
                            pathString,@"path",
                            @"false",@"remove_src",
                            @"true",@"accurate_progress",
                            @"SYNO.FileStation.CopyMove",@"api",
                            @"start",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_MVCP.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)copyProgressV4_3
{
    if (copyTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"success"] boolValue])
            {
                bool copyRunning = ![[[JSON objectForKey:@"data"] objectForKey:@"finished"] boolValue];
                float progress = [[[JSON objectForKey:@"data"] objectForKey:@"progress"] floatValue];
                if (progress != -1.0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCopyProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithFloat:progress],@"progress",
                                                       nil]];
                    });
                }
                if (copyRunning)
                {
                    // Update progress
                    [self performSelector:@selector(copyProgress)
                               withObject:nil
                               afterDelay:2];
                }
                else{
                    // Copy is now finished
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:YES],@"success",
                                                       nil]];
                    });
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   @"Unknown error",@"error",
                                                   nil]];
                });
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error localizedDescription],@"error",
                                               nil]];
            });
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                copyTaskID,@"taskid",
                                @"SYNO.FileStation.CopyMove",@"api",
                                @"status",@"method",
                                @"1",@"version",
                                nil];

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_MVCP.cgi?SynoToken=%@",synoToken]]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelCopyTaskV4_3
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
        
        NSLog(@"%@", error);
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            copyTaskID,@"taskid",
                            @"SYNO.FileStation.CopyMove",@"api",
                            @"stop",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_MVCP.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - copy management DSM v3.x

- (void)copyFilesV3_X:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            if (dsmVersion >= SYNOLOGY_DSM_3_0)
            {
                copyTaskID = [JSON objectForKey:@"taskid"];
            }
            else if ([JSON objectForKey:@"pid"])
            {
                copyTaskID = [JSON objectForKey:@"pid"];
            }
            [self performSelector:@selector(copyProgress) withObject:nil afterDelay:0.2];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [error description],@"error",
                                           nil]];
        });
    };
    
    NSMutableString *filesString = [NSMutableString string];
    
    for (FileItem *file in files)
    {
        [filesString appendString:file.path];
        if (file != [files lastObject])
        {
            [filesString appendString:@"_SYNOFM_"];
        }
    }
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            filesString,@"files",
                            destFolder.path,@"destpath",
                            overwrite?@"true":@"false",@"overwrite",
                            @"copy",@"action",
                            nil];

    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_MVCP.cgi";
    }
    else
    {
        urlPath = @"webfm/webUI/file_MVCP.cgi";
    }

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)copyProgressV3_X
{
    if (copyTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[[JSON objectForKey:@"data"] objectForKey:@"result"] isEqualToString:@"fail"])
            {
                NSString *message = nil;
                if ([[JSON objectForKey:@"data"] objectForKey:@"errno"])
                {
                    message = [[[JSON objectForKey:@"data"] objectForKey:@"errno"] objectForKey:@"key"];
                }
                else if ([[JSON objectForKey:@"data"] objectForKey:@"errItems"])
                {
                    message = [NSString string];
                    for (NSDictionary *error in [[JSON objectForKey:@"data"] objectForKey:@"errItems"])
                    {
                        message = [message stringByAppendingFormat:@"%@ : %@\n",
                                   [[[error objectForKey:@"name"] componentsSeparatedByString:@"/"] lastObject],
                                   [error objectForKey:@"key"]];
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   message,@"error",
                                                   nil]];
                });
            }
            else
            {
                if ([[JSON objectForKey:@"success"] boolValue])
                {
                    bool copyRunning = ![[JSON objectForKey:@"finished"] boolValue];
                    float progress = [[JSON objectForKey:@"progress"] floatValue];
                    if (progress == -1.0)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:NO],@"success",
                                                           @"Unknown error",@"error",
                                                           nil]];
                        });
                    }
                    else
                    {
                        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithFloat:progress]
                                                                                           forKey:@"progress"];
                        if ([[JSON objectForKey:@"data"] objectForKey:@"pfile"])
                        {
                            [dict addEntriesFromDictionary:
                             [NSDictionary dictionaryWithObject:[[[[JSON objectForKey:@"data"] objectForKey:@"pfile"] componentsSeparatedByString:@"/"] lastObject]
                                                         forKey:@"info"]];
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMCopyProgress:dict];
                        });
                    }
                    if (copyRunning)
                    {
                        // Update progress
                        [self performSelector:@selector(copyProgress)
                                   withObject:nil
                                   afterDelay:2];
                    }
                    else
                    {
                        // Copy action is now finished
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:YES],@"success",
                                                           nil]];
                        });
                    }
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       @"Unknown error",@"error",
                                                       nil]];
                    });
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
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"/webman/modules/FileBrowser/webfm/webUI/file_MVCP.cgi?action=readprogress&taskid=%@",copyTaskID]]
                parameters:nil
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelCopyTaskV3_X
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
    
    NSDictionary *params = nil;
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"cancelprogress",@"action",
                  copyTaskID,@"taskid",
                  nil];
        
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_MVCP.cgi";
    }
    else
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"cancelMVCP",@"action",
                  @"webUI/file_MVCP.cgi",@"url",
                  copyTaskID,@"pid",
                  nil];
        
        urlPath = @"webfm/webUI/file_MVCP.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
           parameters:params
              success:successBlock
              failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - copy management DSM v2.x

- (void)copyProgressV2_X
{
    if (copyTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"result"] isEqualToString:@"fail"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [[JSON objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                                   nil]];
                });
            }
            else
            {
                if ([[JSON objectForKey:@"success"] boolValue])
                {
                    bool copyRunning = [[JSON objectForKey:@"running"] boolValue];
                    float progress = [[JSON objectForKey:@"progress"] floatValue];
                    if (progress == -1.0)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:NO],@"success",
                                                           @"Unknown error",@"error",
                                                           nil]];
                        });
                    }
                    else
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMCopyProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithFloat:progress],@"progress",
                                                           nil]];
                        });
                    }
                    if (copyRunning)
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
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       @"Unknown error",@"error",
                                                       nil]];
                    });
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error localizedDescription],@"error",
                                               nil]];
            });
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"readMVCPprogress",@"action",
                                @"webUI/file_MVCP.cgi",@"url",
                                copyTaskID,@"pid",
                                nil];

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:@"webfm/webUI/file_MVCP.cgi"]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}
#endif

#pragma mark - move management

#ifndef APP_EXTENSION
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self moveFilesV4_3:files toPath:destFolder andOverwrite:overwrite];
    }
    else
    {
        [self moveFilesV3_X:files toPath:destFolder andOverwrite:overwrite];
    }
}

- (void)moveProgress
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self moveProgressV4_3];
    }
    else if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        [self moveProgressV3_X];
    }
    else
    {
        [self moveProgressV2_X];
    }
}

- (void)cancelMoveTask
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self cancelMoveTaskV4_3];
    }
    else
    {
        [self cancelMoveTaskV3_X];
    }
}

#pragma mark - move management DSM v4.3

- (void)moveFilesV4_3:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            moveTaskID = [[JSON objectForKey:@"data"] objectForKey:@"taskid"];
            [self performSelector:@selector(moveProgress) withObject:nil afterDelay:0.2];
        }
        else
        {
            NSString *error = [NSString stringWithFormat:@"Error code %@",[[JSON objectForKey:@"error"] objectForKey:@"code"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               error,@"error",
                                               nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [error localizedDescription],@"error",
                                           nil]];
        });
    };
    
    NSMutableString *pathString = [NSMutableString string];
    
    for (FileItem *file in files)
    {
        [pathString appendFormat:@"%@",[self escapeSynoString:file.fullPath]];
        if (file != [files lastObject])
        {
            [pathString appendString:@","];
        }
    }
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            overwrite?@"true":@"false",@"overwrite",
                            [self escapeSynoString:destFolder.path],@"dest_folder_path",
                            pathString,@"path",
                            @"true",@"remove_src",
                            @"true",@"accurate_progress",
                            @"SYNO.FileStation.CopyMove",@"api",
                            @"start",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_MVCP.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)moveProgressV4_3
{
    if (moveTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"success"] boolValue])
            {
                bool moveRunning = ![[[JSON objectForKey:@"data"] objectForKey:@"finished"] boolValue];
                float progress = [[[JSON objectForKey:@"data"] objectForKey:@"progress"] floatValue];
                if (progress != -1.0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMMoveProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithFloat:progress],@"progress",
                                                       nil]];
                    });
                }
                if (moveRunning)
                {
                    // Update progress
                    [self performSelector:@selector(moveProgress)
                               withObject:nil
                               afterDelay:2];
                }
                else{
                    // Move is now finished
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:YES],@"success",
                                                       nil]];
                    });
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   @"Unknown error",@"error",
                                                   nil]];
                });
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error localizedDescription],@"error",
                                               nil]];
            });
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                moveTaskID,@"taskid",
                                @"SYNO.FileStation.CopyMove",@"api",
                                @"status",@"method",
                                @"1",@"version",
                                nil];

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_MVCP.cgi?SynoToken=%@",synoToken]]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelMoveTaskV4_3
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
        
        NSLog(@"%@", error);
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            moveTaskID,@"taskid",
                            @"SYNO.FileStation.CopyMove",@"api",
                            @"stop",@"method",
                            @"1",@"version",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_MVCP.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - move management DSM v3.X

- (void)moveFilesV3_X:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            moveTaskID = [JSON objectForKey:@"taskid"];
            
            [self performSelector:@selector(moveProgress) withObject:nil afterDelay:0.2];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           [error localizedDescription],@"error",
                                           nil]];
        });
    };
    
    NSMutableString *filesString = [NSMutableString string];
    
    for (FileItem *file in files)
    {
        [filesString appendString:file.path];
        if (file != [files lastObject])
        {
            [filesString appendString:@"_SYNOFM_"];
        }
    }
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            filesString,@"files",
                            destFolder.path,@"destpath",
                            overwrite?@"true":@"false",@"overwrite",
                            @"move",@"action",
                            nil];
    
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_MVCP.cgi";
    }
    else
    {
        urlPath = @"webfm/webUI/file_MVCP.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)moveProgressV3_X
{
    if (moveTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[[JSON objectForKey:@"data"] objectForKey:@"result"] isEqualToString:@"fail"])
            {
                NSString *message = nil;
                if ([[JSON objectForKey:@"data"] objectForKey:@"errno"])
                {
                    message = [[[JSON objectForKey:@"data"] objectForKey:@"errno"] objectForKey:@"key"];
                }
                else if ([[JSON objectForKey:@"data"] objectForKey:@"errItems"])
                {
                    message = [NSString string];
                    for (NSDictionary *error in [[JSON objectForKey:@"data"] objectForKey:@"errItems"])
                    {
                        message = [message stringByAppendingFormat:@"%@ : %@\n",
                                   [[[error objectForKey:@"name"] componentsSeparatedByString:@"/"] lastObject],
                                   [error objectForKey:@"key"]];
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   message,@"error",
                                                   nil]];
                });
            }
            else if ([[JSON objectForKey:@"success"] boolValue])
            {
                bool moveRunning = ![[JSON objectForKey:@"finished"] boolValue];
                float progress = [[JSON objectForKey:@"progress"] floatValue];
                if (progress == -1.0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       @"Unknown error",@"error",
                                                       nil]];
                    });
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMMoveProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithFloat:progress],@"progress",
                                                       nil]];
                    });
                }
                if (moveRunning)
                {
                    // Update progress
                    [self performSelector:@selector(moveProgress)
                               withObject:nil
                               afterDelay:2];
                }
                else
                {
                    // Moving is now finished
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:YES],@"success",
                                                       nil]];
                    });
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   @"Unknown error",@"error",
                                                   nil]];
                });
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error localizedDescription],@"error",
                                               nil]];
            });
        };
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"/webman/modules/FileBrowser/webfm/webUI/file_MVCP.cgi?action=readprogress&taskid=%@",moveTaskID]]
                parameters:nil
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelMoveTaskV3_X
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
    
    NSDictionary *params = nil;
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"cancelprogress",@"action",
                  moveTaskID,@"taskid",
                  nil];
        
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_MVCP.cgi";
    }
    else
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"cancelMVCP",@"action",
                  @"webUI/file_MVCP.cgi",@"url",
                  moveTaskID,@"pid",
                  nil];
        
        urlPath = @"webfm/webUI/file_MVCP.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
           parameters:params
              success:successBlock
              failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - move management DSM v2.x

- (void)moveProgressV2_X
{
    if (moveTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"result"] isEqualToString:@"fail"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [[JSON objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                                   nil]];
                });
            }
            else
            {
                if ([[JSON objectForKey:@"success"] boolValue])
                {
                    bool moveRunning = [[JSON objectForKey:@"running"] boolValue];
                    float progress = [[JSON objectForKey:@"progress"] floatValue];
                    if (progress == -1.0)
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:NO],@"success",
                                                           @"Unknown error",@"error",
                                                           nil]];
                        });
                    }
                    else
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMMoveProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithFloat:progress],@"progress",
                                                           nil]];
                        });
                    }
                    if (moveRunning)
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
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       @"Unknown error",@"error",
                                                       nil]];
                    });
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error localizedDescription],@"error",
                                               nil]];
            });
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"readMVCPprogress",@"action",
                                @"webUI/file_MVCP.cgi",@"url",
                                moveTaskID,@"pid",
                                nil];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:@"webfm/webUI/file_MVCP.cgi"]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}
#endif

#pragma mark - Renaming management

#ifndef APP_EXTENSION
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self renameFileV4_3:oldFile toName:newName atPath:folder];
    }
    else
    {
        [self renameFileV2_X:oldFile toName:newName atPath:folder];
    }
}

- (void)renameFileV4_3:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:YES],@"success",
                                         nil]];
            });
        }
        else
        {
            NSString *error = [NSString stringWithFormat:@"Error code %@",[[JSON objectForKey:@"error"] objectForKey:@"code"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:NO],@"success",
                                         error,@"error",
                                         nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],@"success",
                                     [error localizedDescription],@"error",
                                     nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            [self escapeSynoString:[NSString stringWithFormat:@"%@/%@",folder.path,oldFile.name]],@"path",
                            [self escapeSynoString:newName],@"name",
                            @"SYNO.FileStation.Rename",@"api",
                            @"rename",@"method",
                            @"1",@"version",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_rename.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)renameFileV2_X:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    // DSM 2.x -> 4.2
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
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
                                         [[JSON objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                         nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:NO],@"success",
                                     [error localizedDescription],@"error",
                                     nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"rename",@"action",
                            oldFile.name,@"oldname",
                            newName,@"newname",
                            folder.path,@"fileID",
                            nil];
    
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_rename.cgi";
    }
    else
    {
        urlPath = @"webfm/webUI/file_rename.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}
#endif

#pragma mark - Eject management

#ifndef APP_EXTENSION
- (void)ejectableList
{
    if (dsmVersion >= SYNOLOGY_DSM_5_0)
    {
        [self ejectableListV5_0];
    }
    else if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self ejectableListV4_3];
    }
    else if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        [self ejectableListV3_X];
    }
    else
    {
        [self ejectableListV2_X];
    }
}

- (void)ejectFile:(FileItem *)fileItem
{
    if (dsmVersion >= SYNOLOGY_DSM_5_0)
    {
        [self ejectFileV5_0:fileItem];
    }
    else if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self ejectFileV4_3:fileItem];
    }
    else
    {
        [self ejectFileV3_X:fileItem];
    }
}

#pragma mark - Eject management DSM v5.0

- (void)ejectableListV5_0
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        // Do no handle disconnect here, elseway non admin user will get disconnected
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            NSMutableArray *devicesArray = [NSMutableArray array];
            if ([[[JSON objectForKey:@"data"] objectForKey:@"result"] isKindOfClass:[NSArray class]])
            {
                for (NSDictionary *result in [[JSON objectForKey:@"data"] objectForKey:@"result"])
                {
                    if ([[[result objectForKey:@"data"] objectForKey:@"devices"] isKindOfClass:[NSArray class]])
                    {
                        for (NSDictionary *device in [[result objectForKey:@"data"] objectForKey:@"devices"])
                        {
                            if ([[device objectForKey:@"partitions"] isKindOfClass:[NSArray class]])
                            {
                                for (NSDictionary *partition in [device objectForKey:@"partitions"])
                                {
                                    NSDictionary *deviceElement = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                   [partition objectForKey:@"share_name"],@"folder",
                                                                   [partition objectForKey:@"name_id"],@"ejectname",
                                                                   nil];
                                    
                                    [devicesArray addObject:deviceElement];
                                }
                            }
                        }
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                devicesArray,@"ejectablelist",
                                                nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error localizedDescription],@"error",
                                            nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"[{\"api\":\"SYNO.Core.ExternalDevice.Storage.USB\",\"version\":1,\"method\":\"list\",\"additional\":[\"dev_type\",\"product\",\"status\",\"partitions\"]},{\"api\":\"SYNO.Core.ExternalDevice.Storage.eSATA\",\"version\":1,\"method\":\"list\",\"additional\":[\"dev_type\",\"status\",\"partitions\"]}]",@"compound",
                            @"SYNO.Entry.Request",@"api",
                            @"request",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/entry.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)ejectFileV5_0:(FileItem *)fileItem
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error localizedDescription],@"error",
                                            nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            fileItem.ejectName,@"dev_id",
                            @"SYNO.Core.ExternalDevice.Storage.USB",@"api",
                            @"eject",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/entry.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - Eject management DSM v4.3

- (void)ejectableListV4_3
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        // Do no handle disconnect here, elseway non admin user will get disconnected
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            NSMutableArray *devicesArray = [NSMutableArray array];
            if ([[[JSON objectForKey:@"data"] objectForKey:@"deviceList"] isKindOfClass:[NSArray class]])
            {
                for (NSDictionary *device in [[JSON objectForKey:@"data"] objectForKey:@"deviceList"])
                {
                    if ([device objectForKey:@"partitionList"])
                    {
                        for (NSDictionary *partition in [device objectForKey:@"partitionList"])
                        {
                            NSString *folder = [partition objectForKey:@"sharedfolder"];
                            NSString *ejectableName = [partition objectForKey:@"device_name"];
                            NSDictionary *deviceElement = [NSDictionary dictionaryWithObjectsAndKeys:
                                                           folder,@"folder",
                                                           ejectableName,@"ejectname",
                                                           nil];
                            
                            [devicesArray addObject:deviceElement];
                        }
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                devicesArray,@"ejectablelist",
                                                nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error localizedDescription],@"error",
                                            nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"load",@"action",
                            @"true",@"load_device",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webman/modules/ControlPanel/modules/externaldevices.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)ejectFileV4_3:(FileItem *)fileItem
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error localizedDescription],@"error",
                                            nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"apply",@"action",
                            fileItem.ejectName,@"device_name",
                            @"usbDisk",@"device_type",
                            fileItem.name,@"device_display_name",
                            @"true",@"eject_usb",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webman/modules/ControlPanel/modules/externaldevices.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - Eject management DSM v3.x

- (void)ejectableListV3_X
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        // Do no handle disconnect here, elseway non admin user will get disconnected
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            NSMutableArray *devicesArray = [NSMutableArray array];
            if ([[[JSON objectForKey:@"data"] objectForKey:@"deviceList"] isKindOfClass:[NSArray class]])
            {
                for (NSDictionary *device in [[JSON objectForKey:@"data"] objectForKey:@"deviceList"])
                {
                    if ([device objectForKey:@"partitionList"])
                    {
                        for (NSDictionary *partition in [device objectForKey:@"partitionList"])
                        {
                            NSString *folder = [partition objectForKey:@"sharedfolder"];
                            NSString *ejectableName = [partition objectForKey:@"device_name"];
                            NSDictionary *deviceElement = [NSDictionary dictionaryWithObjectsAndKeys:
                                                           folder,@"folder",
                                                           ejectableName,@"ejectname",
                                                           nil];
                            
                            [devicesArray addObject:deviceElement];
                        }
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                devicesArray,@"ejectablelist",
                                                nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error localizedDescription],@"error",
                                            nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"load",@"action",
                            @"true",@"load_device",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"webman/modules/ControlPanel/modules/externaldevices.cgi"]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)ejectFileV3_X:(FileItem *)fileItem
{
    // DSM 2.0 -> 4.2
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error localizedDescription],@"error",
                                            nil]];
        });
    };
    
    NSDictionary *params = nil;
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"apply",@"action",
                  fileItem.ejectName,@"device_name",
                  @"",@"printerid",
                  @"",@"printer_mode",
                  @"true",@"eject_usb",
                  nil];
        
        urlPath = @"webman/modules/ControlPanel/modules/externaldevices.cgi";
    }
    else
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"apply",@"action",
                  @"eject",@"operation",
                  fileItem.ejectName,@"device",
                  nil];
        
        urlPath = @"webman/modules/usbdisk.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - Eject management DSM v2.x

- (void)ejectableListV2_X
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        // Do no handle disconnect here, elseway non admin user will get disconnected
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            NSMutableArray *devicesArray = [NSMutableArray array];
            if ([[JSON objectForKey:@"data"] isKindOfClass:[NSArray class]])
            {
                for (NSDictionary *device in [JSON objectForKey:@"data"])
                {
                    NSString *folder = [device objectForKey:@"sharedfolder"];
                    NSString *ejectableName = [device objectForKey:@"device"];
                    NSDictionary *deviceElement = [NSDictionary dictionaryWithObjectsAndKeys:
                                                   folder,@"folder",
                                                   ejectableName,@"ejectname",
                                                   nil];
                    
                    [devicesArray addObject:deviceElement];
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                devicesArray,@"ejectablelist",
                                                nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMEjectableList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [error localizedDescription],@"error",
                                            nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"load",@"action",
                            @"true",@"load_device",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"webman/modules/usbdisk.cgi"]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}
#endif

#pragma mark - Extract management

#ifndef APP_EXTENSION
- (void)extractFiles:(NSArray *)files toFolder:(FileItem *)folder withPassword:(NSString *)password overwrite:(BOOL)overwrite extractWithFolder:(BOOL)extractFolders
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self extractFilesV4_3:files
                      toFolder:folder
                  withPassword:password
                     overwrite:overwrite
             extractWithFolder:extractFolders];
    }
    else
    {
        [self extractFilesV3_X:files
                      toFolder:folder
                  withPassword:password
                     overwrite:overwrite
             extractWithFolder:extractFolders];
    }
}

- (void)extractProgress
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self extractProgressV4_3];
    }
    else if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        [self extractProgressV3_X];
    }
    else
    {
        [self extractProgressV2_X];
    }
}

- (void)cancelExtractTask
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self cancelExtractTaskV4_3];
    }
    else
    {
        [self cancelExtractTaskV3_X];
    }
}

#pragma mark - Extract management DSM v4.3

- (void)extractFilesV4_3:(NSArray *)files
                toFolder:(FileItem *)folder
            withPassword:(NSString *)password
               overwrite:(BOOL)overwrite
       extractWithFolder:(BOOL)extractFolders
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            extractTaskID = [[JSON objectForKey:@"data"] objectForKey:@"taskid"];
            [self performSelector:@selector(extractProgress) withObject:nil afterDelay:0.2];
        }
        else
        {
            NSString *error = [NSString stringWithFormat:@"Error code %@",[[operation.responseObject objectForKey:@"error"] objectForKey:@"code"]];

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:NO],@"success",
                                                  error,@"error",
                                                  nil]];
                
                extractFilesList = nil;
                extractPassword = nil;
                extractFolder = nil;
            });
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
        
        extractFilesList = nil;
        extractPassword = nil;
        extractFolder = nil;
    };
    
    extractFilesList = [NSMutableArray arrayWithArray:files];
    extractFolder = folder;
    extractPassword = password;
    extractOverwrite = overwrite;
    extractWithFolder = extractFolders;
    
    FileItem *fileItem = [extractFilesList firstObject];

    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   overwrite?@"true":@"false",@"mode",
                                   [self escapeSynoString:fileItem.fullPath],@"file_path",
                                   [self escapeSynoString:folder.path],@"dest_folder_path",
                                   extractFolders?@"true":@"false",@"keep_dir",
                                   @"SYNO.FileStation.Extract",@"api",
                                   @"start",@"method",
                                   @"1",@"version",
                                   nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_extract.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)extractProgressV4_3
{
    if (extractTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"success"] boolValue])
            {
                bool extractRunning = ![[[JSON objectForKey:@"data"] objectForKey:@"finished"] boolValue];
                float extractProgress = [[[JSON objectForKey:@"data"] objectForKey:@"progress"] floatValue];
                if ([[JSON objectForKey:@"data"] objectForKey:@"errors"])
                {
                    NSString *error = [NSString stringWithFormat:NSLocalizedString(@"Error %@", nil),[[[[JSON objectForKey:@"data"] objectForKey:@"errors"] objectAtIndex:0]objectForKey:@"code"]];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          [NSNumber numberWithBool:NO],@"success",
                                                          error,@"error",
                                                          nil]];
                    });
                    
                    extractFilesList = nil;
                    extractPassword = nil;
                    extractFolder = nil;
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMExtractProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          [NSNumber numberWithFloat:extractProgress],@"progress",
                                                          [[[JSON objectForKey:@"data"] objectForKey:@"processing_path"] lastPathComponent],@"currentFile",
                                                          nil]];
                    });
                }
                if (extractRunning)
                {
                    // Update progress
                    [self performSelector:@selector(extractProgress) withObject:nil afterDelay:2];
                }
                else
                {
                    [extractFilesList removeObjectAtIndex:0];
                    if ([extractFilesList count] == 0)
                    {
                        // Extract is now finished
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                              [NSNumber numberWithBool:YES],@"success",
                                                              nil]];
                        });
                    }
                    else
                    {
                        // Extract next file
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self extractFiles:extractFilesList
                                      toFolder:extractFolder
                                  withPassword:extractPassword
                                     overwrite:extractOverwrite
                             extractWithFolder:extractWithFolder];
                        });
                    }
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:NO],@"success",
                                                      @"Unknown error",@"error",
                                                      nil]];
                });
                
                extractFilesList = nil;
                extractPassword = nil;
                extractFolder = nil;
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
            
            extractFilesList = nil;
            extractPassword = nil;
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                extractTaskID,@"taskid",
                                @"SYNO.FileStation.Extract",@"api",
                                @"status",@"method",
                                @"1",@"version",
                                nil];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_extract.cgi?SynoToken=%@",synoToken]]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelExtractTaskV4_3
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        extractTaskID = nil;
        extractFilesList = nil;
        extractPassword = nil;
        extractFolder = nil;
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        extractTaskID = nil;
        extractFilesList = nil;
        extractPassword = nil;
        extractFolder = nil;
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            extractTaskID,@"taskid",
                            @"SYNO.FileStation.Extract",@"api",
                            @"stop",@"method",
                            @"1",@"version",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_extract.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - Extract management DSM v3.X

- (void)extractFilesV3_X:(NSArray *)files
                toFolder:(FileItem *)folder
            withPassword:(NSString *)password
               overwrite:(BOOL)overwrite
       extractWithFolder:(BOOL)extractFolders
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            if (dsmVersion >= SYNOLOGY_DSM_3_0)
            {
                extractTaskID = [JSON objectForKey:@"taskid"];
            }
            else
            {
                extractTaskID = [JSON objectForKey:@"pid"];
            }
            [self performSelector:@selector(extractProgress) withObject:nil afterDelay:0.2];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:NO],@"success",
                                                  [[JSON objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                                  nil]];
            });
            
            extractFilesList = nil;
            extractPassword = nil;
            extractFolder = nil;
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
        
        extractFilesList = nil;
        extractPassword = nil;
        extractFolder = nil;
    };
    
    FileItem *fileItem = [files firstObject];

    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"extract",@"action",
                                   overwrite?@"overwrite":@"skip",@"mode",
                                   folder.path,@"dest",
                                   extractFolders?@"full":@"none",@"pathmode",
                                   @"true",@"mkdir",
                                   nil];
    
    if (dsmVersion >= SYNOLOGY_DSM_4_1)
    {
        [params addEntriesFromDictionary:[NSDictionary dictionaryWithObject:fileItem.path
                                                                     forKey:@"zipfile"]];
    }
    else
    {
        [params addEntriesFromDictionary:[NSDictionary dictionaryWithObject:fileItem.fullPath
                                                                     forKey:@"zipfile"]];
    }
    
    if ((password) && (![password isEqualToString:@""]))
    {
        [params addEntriesFromDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                          password,@"pass",
                                          @"enu",@"usecp",
                                          nil]];
    }
    
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_extract.cgi";
    }
    else
    {
        urlPath = @"webfm/webUI/file_extract.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)extractProgressV3_X
{
    if (extractTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[[JSON objectForKey:@"data"] objectForKey:@"result"] isEqualToString:@"fail"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:NO],@"success",
                                                      NSLocalizedString([[[JSON objectForKey:@"data"] objectForKey:@"errno"] objectForKey:@"key"],nil),@"error",
                                                      nil]];
                });
                
                extractFilesList = nil;
                extractPassword = nil;
                extractFolder = nil;
            }
            else if ([[JSON objectForKey:@"success"] boolValue])
            {
                bool extractRunning = ![[JSON objectForKey:@"finished"] boolValue];
                float extractProgress = [[JSON objectForKey:@"progress"] floatValue];
                if (extractProgress == -1.0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          [NSNumber numberWithBool:NO],@"success",
                                                          @"TODO",@"error",
                                                          nil]];
                    });
                    
                    extractFilesList = nil;
                    extractPassword = nil;
                    extractFolder = nil;
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMExtractProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          [[JSON objectForKey:@"data"] objectForKey:@"pfile"],@"currentFile",
                                                          [NSNumber numberWithFloat:extractProgress],@"progress",
                                                          nil]];
                    });
                }
                if (extractRunning)
                {
                    // Update progress
                    [self performSelector:@selector(extractProgress) withObject:nil afterDelay:2];
                }
                else
                {
                    [extractFilesList removeObjectAtIndex:0];
                    if ([extractFilesList count] == 0)
                    {
                        // Extract is now finished
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                              [NSNumber numberWithBool:YES],@"success",
                                                              nil]];
                        });
                    }
                    else
                    {
                        // Extract next file
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self extractFiles:extractFilesList
                                      toFolder:extractFolder
                                  withPassword:extractPassword
                                     overwrite:extractOverwrite
                             extractWithFolder:extractWithFolder];
                        });
                    }
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:NO],@"success",
                                                      @"Unknown error",@"error",
                                                      nil]];
                });

                extractFilesList = nil;
                extractPassword = nil;
                extractFolder = nil;
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
            
            extractFilesList = nil;
            extractPassword = nil;
            extractFolder = nil;
        };
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"webman/modules/FileBrowser/webfm/webUI/file_extract.cgi?action=readprogress&taskid=%@",extractTaskID]]
               parameters:nil
                  success:successBlock
                  failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelExtractTaskV3_X
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        extractTaskID = nil;
        extractFilesList = nil;
        extractPassword = nil;
        extractFolder = nil;
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        extractTaskID = nil;
        extractFilesList = nil;
        extractPassword = nil;
        extractFolder = nil;
    };
    
    NSDictionary *params = nil;
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"cancelprogress",@"action",
                  extractTaskID,@"taskid",
                  nil];
        
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_extract.cgi";
    }
    else
    {
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  @"cancelextract",@"action",
                  @"webUI/file_extract.cgi",@"url",
                  extractTaskID,@"pid",
                  nil];
        
        urlPath = @"webfm/webUI/file_extract.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
           parameters:params
              success:successBlock
              failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - Extract management DSM v2.X

- (void)extractProgressV2_X
{
    if (extractTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"result"] isEqualToString:@"fail"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:NO],@"success",
                                                      [[JSON objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                                      nil]];
                });

                extractFilesList = nil;
                extractPassword = nil;
                extractFolder = nil;
            }
            else
            {
                BOOL extractRunning = [[JSON objectForKey:@"success"] boolValue];
                if (extractRunning)
                {
                    if ([[JSON objectForKey:@"running"] boolValue])
                    {
                        // Update progress
                        [self performSelector:@selector(extractProgress)
                                   withObject:nil
                                   afterDelay:2];
                    }
                    else
                    {
                        [extractFilesList removeObjectAtIndex:0];
                        if ([extractFilesList count] == 0)
                        {
                            // Extract is now finished
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                  [NSNumber numberWithBool:YES],@"success",
                                                                  nil]];
                            });
                        }
                        else
                        {
                            // Extract next file
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self extractFiles:extractFilesList
                                          toFolder:extractFolder
                                      withPassword:extractPassword
                                         overwrite:extractOverwrite
                                 extractWithFolder:extractWithFolder];
                            });
                        }
                    }
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          [NSNumber numberWithBool:NO],@"success",
                                                          @"Unknown error",@"error",
                                                          nil]];
                    });

                    extractFilesList = nil;
                    extractPassword = nil;
                    extractFolder = nil;
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
            
            extractFilesList = nil;
            extractPassword = nil;
            extractFolder = nil;
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"readProgress",@"action",
                                @"webUI/file_extract.cgi",@"url",
                                extractTaskID,@"pid",
                                nil];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:@"webfm/webUI/file_extract.cgi"]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}
#endif

#pragma mark - Compress management

#ifndef APP_EXTENSION
- (void)compressFiles:(NSArray *)files
            toArchive:(NSString *)archive
          archiveType:(ARCHIVE_TYPE)archiveType
     compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel
             password:(NSString *)password
            overwrite:(BOOL)overwrite
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self compressFilesV4_3:files
                      toArchive:archive
                    archiveType:archiveType
               compressionLevel:compressionLevel
                       password:password
                      overwrite:overwrite];
    }
    else
    {
        [self compressFilesV3_X:files
                      toArchive:archive
                    archiveType:archiveType
               compressionLevel:compressionLevel
                       password:password
                      overwrite:overwrite];
    }
}

- (void)compressProgress
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self compressProgressV4_3];
    }
    else if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        [self compressProgressV3_X];
    }
    else
    {
        [self compressProgressV2_X];
    }
}

- (void)cancelCompressTask
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self cancelCompressTaskV4_3];
    }
    else
    {
        [self cancelCompressTaskV3_X];
    }
}

#pragma mark - Compress management DSM v4.3

- (void)compressFilesV4_3:(NSArray *)files
                toArchive:(NSString *)archive
              archiveType:(ARCHIVE_TYPE)archiveType
         compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel
                 password:(NSString *)password
                overwrite:(BOOL)overwrite
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            compressTaskID = [[JSON objectForKey:@"data"] objectForKey:@"taskid"];
            [self performSelector:@selector(compressProgressV4_3) withObject:nil afterDelay:0.2];
        }
        else
        {
            NSString *error = [NSString stringWithFormat:@"Error code %@",[[JSON objectForKey:@"error"] objectForKey:@"code"]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   error,@"error",
                                                   nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error localizedDescription],@"error",
                                               nil]];
        });
    };
    
    NSMutableString *pathString = [NSMutableString string];
    
    for (FileItem *file in files)
    {
        [pathString appendFormat:@"%@",[self escapeSynoString:file.fullPath]];
        if (file != [files lastObject])
        {
            [pathString appendString:@","];
        }
    }
    
    NSString *level = nil;
    switch (compressionLevel)
    {
        case ARCHIVE_COMPRESSION_LEVEL_NONE:
        {
            level = @"store";
            break;
        }
        case ARCHIVE_COMPRESSION_LEVEL_FASTEST:
        {
            level = @"fastest";
            break;
        }
        case ARCHIVE_COMPRESSION_LEVEL_NORMAL:
        {
            level = @"normal";
            break;
        }
        case ARCHIVE_COMPRESSION_LEVEL_BEST:
        {
            level = @"best";
            break;
        }
        default:
        {
            level = @"normal";
            break;
        }
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   pathString,@"path",
                                   [self escapeSynoString:archive],@"dest_file_path",
                                   level,@"level",
                                   @"replace",@"mode",
                                   @"SYNO.FileStation.Compress",@"api",
                                   @"start",@"method",
                                   @"1",@"version",
                                   nil];
    
    if ((password) && ([password length]!= 0))
    {
        [params addEntriesFromDictionary:[NSDictionary dictionaryWithObject:password forKey:@"passwd"]];
    }
    else
    {
        [params addEntriesFromDictionary:[NSDictionary dictionaryWithObject:@"" forKey:@"passwd"]];
    }
    
    switch (archiveType)
    {
        case ARCHIVE_TYPE_ZIP:
        {
            [params addEntriesFromDictionary:[NSDictionary dictionaryWithObject:@"zip" forKey:@"format"]];
            break;
        }
        case ARCHIVE_TYPE_7Z:
        {
            [params addEntriesFromDictionary:[NSDictionary dictionaryWithObject:@"7z" forKey:@"format"]];
            break;
        }
        default:
            break;
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_compress.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)compressProgressV4_3
{
    if (compressTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"success"] boolValue])
            {
                bool compressRunning = ![[[JSON objectForKey:@"data"] objectForKey:@"finished"] boolValue];
                if ([[JSON objectForKey:@"data"] objectForKey:@"errors"])
                {
                    NSString *error = [NSString stringWithFormat:NSLocalizedString(@"Error %@", nil),[[[[JSON objectForKey:@"data"] objectForKey:@"errors"] objectAtIndex:0]objectForKey:@"code"]];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:NO],@"success",
                                                           error,@"error",
                                                           nil]];
                    });
                }
                if (compressRunning)
                {
                    // Update progress
                    [self performSelector:@selector(compressProgress) withObject:nil afterDelay:2];
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:YES],@"success",
                                                           nil]];
                    });
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       @"Unknown error",@"error",
                                                       nil]];
                });
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [error localizedDescription],@"error",
                                                   nil]];
            });
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                compressTaskID,@"taskid",
                                @"SYNO.FileStation.Compress",@"api",
                                @"status",@"method",
                                @"1",@"version",
                                nil];

        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_compress.cgi?SynoToken=%@",synoToken]]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelCompressTaskV4_3
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        compressTaskID = nil;
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        compressTaskID = nil;
        
        NSLog(@"%@", error);
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            compressTaskID,@"taskid",
                            @"SYNO.FileStation.Compress",@"api",
                            @"stop",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_compress.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - Compress management DSM v3.X

- (void)compressFilesV3_X:(NSArray *)files
                toArchive:(NSString *)archive
              archiveType:(ARCHIVE_TYPE)archiveType
         compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel
                 password:(NSString *)password
                overwrite:(BOOL)overwrite
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            if (dsmVersion >= SYNOLOGY_DSM_3_0)
            {
                compressTaskID = [JSON objectForKey:@"taskid"];
                [self performSelector:@selector(compressProgress) withObject:nil afterDelay:0.2];
            }
            else
            {
                compressTaskID = [JSON objectForKey:@"pid"];
                [self performSelector:@selector(compressProgress2) withObject:nil afterDelay:0.2];
            }
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error localizedDescription],@"error",
                                               nil]];
        });
    };
    
    NSMutableString *filesString = [NSMutableString string];
    
    for (FileItem *file in files)
    {
        [filesString appendString:file.name];
        if (file != [files lastObject])
        {
            [filesString appendString:@"_SYNOFM_"];
        }
    }
    
    NSString *level = nil;
    switch (compressionLevel)
    {
        case ARCHIVE_COMPRESSION_LEVEL_NONE:
        {
            level = @"store";
            break;
        }
        case ARCHIVE_COMPRESSION_LEVEL_FASTEST:
        {
            level = @"fastest";
            break;
        }
        case ARCHIVE_COMPRESSION_LEVEL_NORMAL:
        {
            level = @"normal";
            break;
        }
        case ARCHIVE_COMPRESSION_LEVEL_BEST:
        {
            level = @"best";
            break;
        }
        default:
        {
            level = @"normal";
            break;
        }
    }
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   filesString,@"files",
                                   ((FileItem *)[files objectAtIndex:0]).shortPath,@"curDir",
                                   [[archive componentsSeparatedByString:@"/"] lastObject],@"zipname",
                                   @"compress",@"action",
                                   level,@"level",
                                   @"",@"mode",
                                   nil];
    if ((password) && ([password length]!= 0))
    {
        [params addEntriesFromDictionary:[NSDictionary dictionaryWithObject:password forKey:@"passwd"]];
    }
    else
    {
        [params addEntriesFromDictionary:[NSDictionary dictionaryWithObject:@"" forKey:@"passwd"]];
    }
    
    switch (archiveType)
    {
        case ARCHIVE_TYPE_ZIP:
        {
            [params addEntriesFromDictionary:[NSDictionary dictionaryWithObject:@"zip" forKey:@"format"]];
            break;
        }
        case ARCHIVE_TYPE_7Z:
        {
            [params addEntriesFromDictionary:[NSDictionary dictionaryWithObject:@"7z" forKey:@"format"]];
            break;
        }
        default:
            break;
    }
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_compress.cgi";
    }
    else
    {
        urlPath = @"webfm/webUI/file_compress.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)compressProgressV3_X
{
    if (compressTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[[JSON objectForKey:@"data"] objectForKey:@"result"] isEqualToString:@"fail"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       [[[JSON objectForKey:@"data"] objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                                       nil]];
                });
            }
            else if ([[JSON objectForKey:@"success"] boolValue])
            {
                bool compressRunning = ![[JSON objectForKey:@"finished"] boolValue];
                float progress = [[JSON objectForKey:@"progress"] floatValue];
                if (progress == -1.0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:NO],@"success",
                                                           @"Unknown error",@"error",
                                                           nil]];
                    });
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCompressProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithFloat:progress],@"progress",
                                                           nil]];
                    });
                }
                if (compressRunning)
                {
                    // Update progress
                    [self performSelector:@selector(compressProgress)
                               withObject:nil
                               afterDelay:2];
                }
                else
                {
                    // Compression is now finished
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:YES],@"success",
                                                           nil]];
                    });
                }
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       @"Unknown error",@"error",
                                                       nil]];
                });
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [error localizedDescription],@"error",
                                                   nil]];
            });
        };
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"webman/modules/FileBrowser/webfm/webUI/file_compress.cgi?action=readprogress&taskid=%@",compressTaskID]]
                parameters:nil
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelCompressTaskV3_X
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        compressTaskID = nil;
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        compressTaskID = nil;
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"cancelprogress",@"action",
                            compressTaskID,@"taskid",
                            nil];
    
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/file_compress.cgi";
    }
    else
    {
        urlPath = @"webfm/webUI/file_compress.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:urlPath]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - Compress management DSM v2.X

- (void)compressProgressV2_X
{
    if (compressTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"result"] isEqualToString:@"fail"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       [[JSON objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                                       nil]];
                });
            }
            else
            {
                BOOL compressRunning = [[JSON objectForKey:@"success"] boolValue];
                if (compressRunning)
                {
                    if ([[JSON objectForKey:@"running"] boolValue])
                    {
                        // Update progress
                        [self performSelector:@selector(compressProgress)
                                   withObject:nil
                                   afterDelay:2];
                    }
                    else
                    {
                        // Compress is now finished
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                               [NSNumber numberWithBool:YES],@"success",
                                                               nil]];
                        });
                    }
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:NO],@"success",
                                                           @"Unknown error",@"error",
                                                           nil]];
                    });
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [error localizedDescription],@"error",
                                                   nil]];
            });
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"readprogress",@"action",
                                @"webUI/file_compress.cgi",@"url",
                                compressTaskID,@"pid",
                                nil];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:@"webfm/webUI/file_compress.cgi"]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}
#endif

#pragma mark - search management

- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self searchFilesV4_3:searchString atPath:folder];
    }
    else
    {
        [self searchFilesV3_X:searchString atPath:folder];
    }
}

- (void)searchProgress
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self searchProgressV4_3];
    }
    else
    {
        [self searchProgressV3_X];
    }
}

- (void)cancelSearchTask
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self cancelSearchTaskV4_3];
    }
    else
    {
        [self cancelSearchTaskV3_X];
    }
}

#pragma mark - search management DSM v4.3

- (void)searchFilesV4_3:(NSString *)searchString atPath:(FileItem *)folder
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            searchTaskID = [[JSON objectForKey:@"data"] objectForKey:@"taskid"];
            [self performSelector:@selector(searchProgress) withObject:nil afterDelay:0.2];
        }
        else
        {
            NSString *error = [NSString stringWithFormat:@"Error code %@",[[JSON objectForKey:@"error"] objectForKey:@"code"]];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 error,@"error",
                                                 nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             [error localizedDescription],@"error",
                                             nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            folder.path,@"folder_path",
                            @"true",@"recursive",
                            searchString,@"pattern",
                            @"SYNO.FileStation.Search",@"api",
                            @"start",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_find.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)searchProgressV4_3
{
    if (searchTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();
            
            if ([[JSON objectForKey:@"success"] boolValue])
            {
                bool searchRunning = ![[[JSON objectForKey:@"data"] objectForKey:@"finished"] boolValue];
                if ([[JSON objectForKey:@"data"] objectForKey:@"errors"])
                {
                    NSString *error = [NSString stringWithFormat:NSLocalizedString(@"Error %@", nil),[[[[JSON objectForKey:@"data"] objectForKey:@"errors"] objectAtIndex:0]objectForKey:@"code"]];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         error,@"error",
                                                         nil]];
                    });
                }
                if (searchRunning)
                {
                    // Search progress
                    [self performSelector:@selector(searchProgress) withObject:nil afterDelay:2];
                }
                else
                {
                    // search is now finished
                    if ([[[JSON objectForKey:@"data"] objectForKey:@"files"] isKindOfClass:[NSArray class]])
                    {
                        NSMutableArray *filesOutputArray = [NSMutableArray array];
                        for (NSDictionary *file in [[JSON objectForKey:@"data"] objectForKey:@"files"])
                        {
                            NSNumber *size = [NSNumber numberWithInt:0];
                            if ([[file objectForKey:@"additional"] objectForKey:@"size"])
                            {
                                size = [NSNumber numberWithLongLong:[[[file objectForKey:@"additional"] objectForKey:@"size"] longLongValue]];
                            }
                            
                            bool iscompressed = [self isCompressed:[[file objectForKey:@"additional"] objectForKey:@"type"]];
                            
                            NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                                      [file objectForKey:@"isdir"],@"isdir",
                                                      [file objectForKey:@"name"],@"filename",
                                                      [file objectForKey:@"path"],@"path",
                                                      size,@"filesizenumber",
                                                      [[[file objectForKey:@"additional"] objectForKey:@"owner"] objectForKey:@"group"],@"group",
                                                      [[[file objectForKey:@"additional"] objectForKey:@"owner"] objectForKey:@"user"],@"owner",
                                                      iscompressed?@"1":@"0",@"iscompressed",
                                                      [NSNumber numberWithBool:YES],@"writeaccess",
                                                      [[[file objectForKey:@"additional"] objectForKey:@"time"] objectForKey:@"mtime"],@"date",
                                                      [[file objectForKey:@"additional"] objectForKey:@"type"],@"type",
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
                }
            }
            else
            {
                NSString *error = [NSString stringWithFormat:@"Error code %@",[[JSON objectForKey:@"error"] objectForKey:@"code"]];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     error,@"error",
                                                     nil]];
                });
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [error localizedDescription],@"error",
                                                 nil]];
            });
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"real_path,size,owner,time,perm,type",@"additional",
                                searchTaskID,@"taskid",
                                @"0",@"offset",
                                @"1000",@"limit",
                                @"all",@"filetype",
                                @"SYNO.FileStation.Search",@"api",
                                @"list",@"method",
                                @"1",@"version",
                                nil];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_find.cgi?SynoToken=%@",synoToken]]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelSearchTaskV4_3
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        searchTaskID = nil;
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        searchTaskID = nil;
        
        NSLog(@"%@", error);
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            searchTaskID,@"taskid",
                            @"SYNO.FileStation.Search",@"api",
                            @"stop",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_find.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - search management DSM v3.x

- (void)searchFilesV3_X:(NSString *)searchString atPath:(FileItem *)folder
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            searchTaskID = [JSON objectForKey:@"taskid"];
            [self performSelector:@selector(searchProgress) withObject:nil afterDelay:0.2];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
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
            [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             [error localizedDescription],@"error",
                                             nil]];
        });
    };
    
    NSString *urlPath = [[self createUrl] stringByAppendingFormat:@"webman/modules/FileBrowser/webfm/webUI/file_find.cgi?action=find&location=%@&keyword=%@",
                         [folder.path encodeStringUrl:NSUTF8StringEncoding],
                         [searchString encodeStringUrl:NSUTF8StringEncoding]];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:urlPath
           parameters:nil
              success:successBlock
              failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)searchProgressV3_X
{
    if (searchTaskID)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            HandleServerDisconnection();

            if (([JSON objectForKey:@"data"]) && (![[JSON objectForKey:@"data"] isKindOfClass:[NSNull class]]))
            {
                if ([[[JSON objectForKey:@"data"] objectForKey:@"result"] isEqualToString:@"fail"])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSNumber numberWithBool:NO],@"success",
                                                         [[[JSON objectForKey:@"data"] objectForKey:@"errno"] objectForKey:@"key"],@"error",
                                                         nil]];
                    });
                }
                else
                {
                    if ([[JSON objectForKey:@"success"] boolValue])
                    {
                        bool searchRunning = ![[JSON objectForKey:@"finished"] boolValue];
                        if (searchRunning)
                        {
                            // Update search
                            [self performSelector:@selector(searchProgress)
                                       withObject:nil
                                       afterDelay:2];
                        }
                        else
                        {
                            // search is now finished
                            if ([[JSON objectForKey:@"items"] isKindOfClass:[NSArray class]])
                            {
                                NSMutableArray *filesOutputArray = [NSMutableArray array];
                                for (NSDictionary *file in [JSON objectForKey:@"items"])
                                {
                                    NSNumber *size = [NSNumber numberWithInt:0];
                                    if ([file objectForKey:@"size"])
                                    {
                                        size = [NSNumber numberWithLongLong:[[file objectForKey:@"size"] longLongValue]];
                                    }
                                    else if ([file objectForKey:@"filesize"])
                                    {
                                        // This is needed to handle old firmwares
                                        size = [[file objectForKey:@"filesize"] valueForStringBytes];
                                    }
                                    
                                    NSNumber *iscompressed = [NSNumber numberWithBool:[[file objectForKey:@"is_compressed"] boolValue]];
                                    
                                    NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                                              [file objectForKey:@"isdir"],@"isdir",
                                                              [file objectForKey:@"filename"],@"filename",
                                                              [file objectForKey:@"file_id"],@"path",
                                                              [file objectForKey:@"path"],@"fullpath",
                                                              size,@"filesizenumber",
                                                              [file objectForKey:@"group"],@"group",
                                                              [file objectForKey:@"owner"],@"owner",
                                                              iscompressed,@"iscompressed",
                                                              [NSNumber numberWithBool:YES],@"writeaccess",
                                                              [file objectForKey:@"mt"],@"date",
                                                              [file objectForKey:@"type"],@"type",
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
                        }
                    }
                    else
                    {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             [JSON objectForKey:@"success"],@"success",
                                                             @"Unknown error",@"error",
                                                             nil]];
                        });
                    }
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [error localizedDescription],@"error",
                                                 nil]];
            });
        };
        
        NSString *urlPath = [self createUrlWithPath:[NSString stringWithFormat:@"webman/modules/FileBrowser/webfm/webUI/file_find.cgi?action=readremain&taskid=%@&start=0&limit=5000&need=all",
                          searchTaskID]];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager GET:urlPath
               parameters:nil
                  success:successBlock
                  failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

- (void)cancelSearchTaskV3_X
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        searchTaskID = nil;
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        searchTaskID = nil;
    };
    
    NSString *urlPath = [self createUrlWithPath:[NSString stringWithFormat:@"webman/modules/FileBrowser/webfm/webUI/file_find.cgi?action=cancel&taskid=%@",
                      searchTaskID]];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:urlPath
           parameters:nil
              success:successBlock
              failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - Share management

#ifndef APP_EXTENSION
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self shareFilesV4_3:files duration:duration password:password];
    }
    else
    {
        //FIXME: check if available
    }
}

- (void)shareFilesPasswordByIdV4_3:(NSArray *)ids password:(NSString *)password
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if (![[JSON objectForKey:@"success"] boolValue])
        {
            NSString *error = [NSString stringWithFormat:@"Error %@ while setting password",
                               [[JSON objectForKey:@"error"] objectForKey:@"code"]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                error,@"error",
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
                                            [error localizedDescription],@"error",
                                            nil]];
        });
    };
    
    NSMutableString *idString = [NSMutableString string];
    for (NSString *shareId in ids)
    {
        [idString appendString:shareId];
        if (shareId != [ids lastObject])
        {
            [idString appendString:@","];
        }
    }

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            idString,@"id",
                            password,@"password",
                            @"{\"Facebook\":\"[]\",\"Google\":\"[]\"}",@"sharing_list",
                            @"SYNO.FileStation.Sharing",@"api",
                            @"edit",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_sharing.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)shareFilesExpirationByIdV4_3:(NSArray *)ids duration:(NSTimeInterval)duration
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if (![[JSON objectForKey:@"success"] boolValue])
        {
            NSString *error = [NSString stringWithFormat:@"Error %@ while setting expiration date",
                               [[JSON objectForKey:@"error"] objectForKey:@"code"]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                error,@"error",
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
                                            [error localizedDescription],@"error",
                                            nil]];
        });
    };
    
    NSMutableString *idString = [NSMutableString string];
    for (NSString *shareId in ids)
    {
        [idString appendString:shareId];
        if (shareId != [ids lastObject])
        {
            [idString appendString:@","];
        }
    }
    
    NSDate *date = [[NSDate alloc]init];
    NSDate *expireDate = [date dateByAddingTimeInterval:duration];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            idString,@"id",
                            [formatter stringFromDate:date],@"date_available",
                            [formatter stringFromDate:expireDate],@"date_expired",
                            @"SYNO.FileStation.Sharing",@"api",
                            @"edit",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_sharing.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)shareFilesV4_3:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([[JSON objectForKey:@"success"] boolValue])
        {
            NSArray *shares = [[JSON objectForKey:@"data"] objectForKey:@"links"];
            NSMutableString *shareString = [NSMutableString string];
            NSMutableArray *idArray = [NSMutableArray array];
            for (NSDictionary *share in shares)
            {
                [shareString appendFormat:@"%@ : %@\r\n",[[share objectForKey:@"path"] lastPathComponent], [share objectForKey:@"url"]];
                [idArray addObject:[share objectForKey:@"id"]];
            }
            if (password.length != 0)
            {
                [self shareFilesPasswordByIdV4_3:idArray password:password];
            }
            if (duration != 0)
            {
                [self shareFilesExpirationByIdV4_3:idArray duration:duration];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                shareString,@"shares",
                                                nil]];
            });
        }
        else
        {
            NSString *error = [NSString stringWithFormat:@"Error code %@",[[JSON objectForKey:@"error"] objectForKey:@"code"]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 error,@"error",
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
                                            [error localizedDescription],@"error",
                                            nil]];
        });
    };
    
    
    NSMutableString *pathString = [NSMutableString string];
    
    for (FileItem *file in files)
    {
        [pathString appendFormat:@"%@",[self escapeSynoString:file.fullPath]];
        if (file != [files lastObject])
        {
            [pathString appendString:@","];
        }
    }

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            pathString,@"path",
                            @"",@"sharing_list",
                            @"SYNO.FileStation.Sharing",@"api",
                            @"create",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"webapi/FileStation/file_sharing.cgi?SynoToken=%@",synoToken]]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
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
        
        lastRequestDate = [NSDate date];
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

    NSString *filename = [file.name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *urlPath = nil;
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        urlPath = [NSString stringWithFormat:@"fbdownload/%@?dlink=%@&SynoToken=%@",[filename encodeStringUrl:NSUTF8StringEncoding],[file.path hexRepresentation],synoToken];
    }
    else if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        urlPath = [NSString stringWithFormat:@"fbdownload/%@?dlink=%@",[filename encodeStringUrl:NSUTF8StringEncoding],[file.path hexRepresentation]];
    }
    else
    {
        urlPath = [NSString stringWithFormat:@"wfmdownload/%@?dlink=%@",[filename encodeStringUrl:NSUTF8StringEncoding],[file.path hexRepresentation]];
    }

    NSURL *url = [NSURL URLWithString:[self createUrlWithPath:urlPath]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    downloadOperation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    // Set destination file
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
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [downloadOperation start];
}

- (void)cancelDownloadTask
{
    // Cancel request
    [downloadOperation cancel];
    
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    
    lastRequestDate = [NSDate date];
}

#pragma mark - upload management

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        [self uploadLocalFileV4_3:file toPath:destFolder overwrite:overwrite];
    }
    else
    {
        [self uploadLocalFileV3_X:file toPath:destFolder overwrite:overwrite];
    }
}

#pragma mark - upload management DSM v4.3

- (void)uploadLocalFileV4_3:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite
{
    __weak typeof(self) weakSelf = self;
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:YES],@"success",
                                                 nil]];
        });
        
        lastRequestDate = [NSDate date];
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if (error.code != kCFURLErrorCancelled)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     [error description],@"error",
                                                     nil]];
            });
        }
    };
    
    // Get modification time of file to upload
    NSError *error = nil;
    NSDictionary *fileAttrib = [[NSFileManager defaultManager] attributesOfItemAtPath:file.fullPath error:&error];
    NSDate *mdate = [fileAttrib objectForKey:NSFileModificationDate];
    NSNumber *fileDateNumber = [NSNumber numberWithDouble:[mdate timeIntervalSince1970]*1000];

    // Build request
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            overwrite?@"true":@"false",@"overwrite",
                            destFolder.path,@"path",
                            fileDateNumber,@"mtime",
                            file.name,@"Filename",
                            destFolder.path, @"toUpload",
                            nil];
    
    void (^bodyConstructorBlock)(id <AFMultipartFormData> formData) =^(id <AFMultipartFormData> formData) {
        NSError *error = nil;
        [formData appendPartWithFileURL:[NSURL fileURLWithPath:file.fullPath] name:@"file" error:&error];
        if (error)
        {
            NSLog(@"error %@",[error description]);
        }
    };
    
    [self.manager.requestSerializer setValue:synoToken forHTTPHeaderField:@"X-SYNO-TOKEN"];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    uploadOperation = [self.manager POST:[self createUrlWithPath:@"webman/modules/FileBrowser/webfm/webUI/html5_upload.cgi"]
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

#pragma mark - upload management DSM v3.x

- (void)uploadLocalFileV3_X:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite
{
    __weak typeof(self) weakSelf = self;

    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        NSLog(@"JSON %@",JSON);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:YES],@"success",
                                             nil]];
        });
        
        lastRequestDate = [NSDate date];
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

    NSString *urlPath = nil;
    NSDictionary *params = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        urlPath = @"webman/modules/FileBrowser/webfm/webUI/html5_upload.cgi";
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  overwrite?@"true":@"false",@"overwrite",
                  destFolder.path,@"path",
                  nil];
    }
    else
    {
        // Get session id
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:[self createUrl]]];
        NSString *session = @"";
        for (NSHTTPCookie *cookie in cookies)
        {
            if ([cookie.name isEqualToString:@"id"])
            {
                session = cookie.value;
                break;
            }
        }
        
        urlPath = [NSString stringWithFormat:@"webfm/webUI/flash_upload.cgi?session=%@&path=%@&overwrite=%@",
                   session,
                   [destFolder.path encodeStringUrl:NSUTF8StringEncoding],
                   overwrite?@"true":@"false"];
        params = [NSDictionary dictionaryWithObjectsAndKeys:
                  file.name,@"Filename",
                  nil];
    }
    
    void (^bodyConstructorBlock)(id <AFMultipartFormData> formData) = nil;
    if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        bodyConstructorBlock =^(id <AFMultipartFormData> formData) {
            NSError *error = nil;
            [formData appendPartWithFileURL:[NSURL fileURLWithPath:file.fullPath]
                                       name:@"Filedata"
                                      error:&error];
            if (error)
            {
                NSLog(@"error %@",[error description]);
            }
        };
    }
    else
    {
        bodyConstructorBlock =^(id <AFMultipartFormData> formData) {
            NSError *error = nil;
            [formData appendPartWithFileURL:[NSURL fileURLWithPath:file.fullPath]
                                       name:@"Filedata"
                                      error:&error];
            if (error)
            {
                NSLog(@"error %@",[error description]);
            }
            [formData appendPartWithFormData:[@"Submit Query" dataUsingEncoding:NSUTF8StringEncoding] name:@"Upload"];
        };
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

    uploadOperation = [self.manager POST:[self createUrlWithPath:@"webman/modules/FileBrowser/webfm/webUI/html5_upload.cgi"]
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
    
    lastRequestDate = [NSDate date];
}

#pragma mark - Reconnection management

- (void)reconnect
{
    // Check if we should reconnect
    NSDate *reconnectionDate = [lastRequestDate dateByAddingTimeInterval:timeoutDuration];
    
    NSLog(@"applicationDidBecomeActive :\nCurrent date : %@\nReconnection date : %@",[NSDate date],reconnectionDate);
    
    if (!([reconnectionDate compare:[NSDate date]] == NSOrderedDescending))
    {
        NSLog(@"Connection timeout, loging again");
        
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            if ([[JSON objectForKey:@"result"] isEqualToString:@"success"])
            {
                if ([JSON objectForKey:@"SynoToken"])
                {
                    synoToken = [JSON objectForKey:@"SynoToken"];
                }
                [self serverData];
            }
            else if ([[JSON objectForKey:@"request_otp"] boolValue])
            {
                // Request 2-Factor authentication One Time Password
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMRequestOTP:nil];
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            [JSON objectForKey:@"reason"],@"error",
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
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                self.userAccount.userName,@"username",
                                [SSKeychain passwordForService:self.userAccount.uuid account:@"password"],@"passwd",
                                @"1",@"service_type",
                                nil];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        self.manager.securityPolicy.allowInvalidCertificates = self.userAccount.acceptUntrustedCertificate;
        
        // Reset HTTP header
        self.manager.requestSerializer = [AFHTTPRequestSerializer serializer];
        
        [self.manager POST:[self createUrlWithPath:@"webman/modules/login.cgi?enable_syno_token=yes"]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
        
        lastRequestDate = [NSDate date];
    }
}

#pragma mark - url management

#ifndef APP_EXTENSION
- (NetworkConnection *)urlForVideo:(FileItem *)file
{
	NSString *filename = [file.name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    // Get session id
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:[self createUrl]]];
    NSString *session = @"";
    for (NSHTTPCookie *cookie in cookies)
    {
        if ([cookie.name isEqualToString:@"id"])
        {
            session = cookie.value;
            break;
        }
    }

    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        networkConnection.url = [NSURL URLWithString:[[self createUrlWithCredentials] stringByAppendingFormat:@"/fbdownload/%@?dlink=%@&SynoToken=%@&_sid=%@",filename,[file.path hexRepresentation],synoToken,session]];
    }
    else if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        networkConnection.url = [NSURL URLWithString:[[self createUrlWithCredentials] stringByAppendingFormat:@"/fbdownload/%@?dlink=%@&_sid=%@",filename,[file.path hexRepresentation],session]];
    }
    else
    {
        networkConnection.url = [NSURL URLWithString:[[self createUrlWithCredentials] stringByAppendingFormat:@"/wfmdownload/%@?dlink=%@&_sid=%@",filename,[file.path hexRepresentation],session]];
    }
    networkConnection.urlType = URLTYPE_HTTP;
    
  	return networkConnection;
}

- (NetworkConnection *)urlForFile:(FileItem *)file
{
	NSString *filename = [file.name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    if (dsmVersion >= SYNOLOGY_DSM_4_3)
    {
        networkConnection.url = [NSURL URLWithString:[self createUrlWithPath:[NSString stringWithFormat:@"fbdownload/%@?dlink=%@&SynoToken=%@",[filename encodeStringUrl:NSUTF8StringEncoding],[file.path hexRepresentation],synoToken]]];
    }
    else if (dsmVersion >= SYNOLOGY_DSM_3_0)
    {
        networkConnection.url = [NSURL URLWithString:[self createUrlWithPath:[NSString stringWithFormat:@"fbdownload/%@?dlink=%@",[filename encodeStringUrl:NSUTF8StringEncoding],[file.path hexRepresentation]]]];

    }
    else
    {
        networkConnection.url = [NSURL URLWithString:[self createUrlWithPath:[NSString stringWithFormat:@"wfmdownload/%@?dlink=%@",[filename encodeStringUrl:NSUTF8StringEncoding],[file.path hexRepresentation]]]];
    }
    networkConnection.urlType = URLTYPE_HTTP;
    
  	return networkConnection;
}
#endif

#pragma mark - supported features

- (long long)supportedFeaturesAtPath:(NSString *)path
{
    long long features = CMSupportedFeaturesNone;
    if (![path isEqualToString:@"/"])
    {
        features = CMSupportedFeaturesMaskFileDelete      |
                   CMSupportedFeaturesMaskFolderDelete    |
                   CMSupportedFeaturesMaskFolderCreate    |
                   CMSupportedFeaturesMaskDeleteCancel    |
                   CMSupportedFeaturesMaskFileRename      |
                   CMSupportedFeaturesMaskFolderRename    |
                   CMSupportedFeaturesMaskFileMove        |
                   CMSupportedFeaturesMaskMoveCancel      |
                   CMSupportedFeaturesMaskFolderMove      |
                   CMSupportedFeaturesMaskFileCopy        |
                   CMSupportedFeaturesMaskFolderCopy      |
                   CMSupportedFeaturesMaskCopyCancel      |
                   CMSupportedFeaturesMaskExtract         |
                   CMSupportedFeaturesMaskExtractMultiple |
                   CMSupportedFeaturesMaskExtractCancel   |
                   CMSupportedFeaturesMaskFileDownload    |
                   CMSupportedFeaturesMaskDownloadCancel  |
                   CMSupportedFeaturesMaskFileUpload      |
                   CMSupportedFeaturesMaskUploadCancel    |
                   CMSupportedFeaturesMaskVLCPlayer; //FIXME: Check why SSL is not working as expected
        
        if (dsmVersion >= SYNOLOGY_DSM_4_3)
        {
            features |= CMSupportedFeaturesMaskFileShare |
                        CMSupportedFeaturesMaskFolderShare;
        }

        if (dsmVersion >= SYNOLOGY_DSM_3_1)
        {
            features |= CMSupportedFeaturesMaskSearch |
                        CMSupportedFeaturesMaskSearchCancel;
        }
        
        if (dsmVersion >= SYNOLOGY_DSM_2_3)
        {
            features |= CMSupportedFeaturesMaskCompress   |
                        CMSupportedFeaturesMaskCompressCancel;
        }
        
        if ((!self.userAccount.boolSSL) || (!self.userAccount.acceptUntrustedCertificate))
        {
            // For now We didn't find a way to use video players to play
            // media on a server with untrusted certificate !
            features |= CMSupportedFeaturesMaskQTPlayer   |
                        CMSupportedFeaturesMaskVLCPlayer  |
                        CMSupportedFeaturesMaskVideoSeek  |
                        CMSupportedFeaturesMaskAirPlay    |
                        CMSupportedFeaturesMaskGoogleCast;
        }
    }
    else
    {
        features |= CMSupportedFeaturesMaskEject |
                    CMSupportedFeaturesMaskGoogleCast;
    }

    return features;
}

#ifndef APP_EXTENSION
- (NSInteger)supportedArchiveType
{
    NSInteger supportedTypes = CMSupportedArchivesMaskZip;
    // Archiving to 7z is supported since DSM 3.1
    if (dsmVersion >= SYNOLOGY_DSM_3_1)
    {
        supportedTypes |= CMSupportedArchivesMask7z;
    }
    return supportedTypes;
}

- (NSInteger)supportedSharingFeatures
{
    NSInteger supportedFeatures = CMSupportedSharingMaskPassword |
                                  CMSupportedSharingMaskValidityPeriod;
    return supportedFeatures;
}

- (SHARING_VALIDITY_UNIT)shareValidityUnit
{
    return SHARING_VALIDITY_UNIT_DAY; // 1 day
}
#endif

#pragma mark - Private methods

- (void)serverModelData
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSDictionary *dict = [JSON objectForKey:@"data"];
        serverModel = [dict objectForKey:@"model"];
        serverFirmwareVersion = [dict objectForKey:@"firmware_ver"];
        NSInteger cores = [[dict objectForKey:@"cpu_cores"] intValue];
        if (cores > 1)
        {
            serverCPUInfo = [NSString stringWithFormat:NSLocalizedString(@"%dx%@ %@@%@ MHz", nil),
                             cores,
                             [dict objectForKey:@"cpu_vendor"],
                             [dict objectForKey:@"cpu_family"],
                             [dict objectForKey:@"cpu_clock_speed"]];
        }
        else
        {
            serverCPUInfo = [NSString stringWithFormat:NSLocalizedString(@"%@ %@@%@ MHz", nil),
                             [dict objectForKey:@"cpu_vendor"],
                             [dict objectForKey:@"cpu_family"],
                             [dict objectForKey:@"cpu_clock_speed"]];
        }
        serverRAMSize = [[dict objectForKey:@"ram_size"] intValue];
        serverSerial = [dict objectForKey:@"serial"];
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"SYNO.Core.System",@"api",
                            @"info",@"method",
                            @"1",@"version",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    if (synoToken)
    {
        [self.manager.requestSerializer setValue:synoToken forHTTPHeaderField:@"X-SYNO-TOKEN"];
    }
    
    [self.manager POST:[self createUrlWithPath:@"webapi/entry.cgi"]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    lastRequestDate = [NSDate date];
}

- (void)serverData
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        protocolVersion = [[[JSON objectForKey:@"Session"] objectForKey:@"version"] intValue];
        timeoutDuration = [[[JSON objectForKey:@"Session"] objectForKey:@"dsm_timeout"] intValue] * 60;

        [self dsmVersion];
        NSLog(@"DSM %f, protocolVersion = %ld",dsmVersion, (long)protocolVersion);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    nil]];
        });
    };

    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        // Try to get the version for old firmwares
        [self oldServerData];
    };

    NSString *path;
    
    if (synoToken)
    {
        path = [NSString stringWithFormat:@"webman/initdata.cgi?SynoToken=%@",synoToken];
    }
    else
    {
        path = @"webman/initdata.cgi";
    }
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:path]
            parameters:nil
               success:successBlock
               failure:failureBlock];
}

- (void)oldServerData
{
    // For old firmwares
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        HandleServerDisconnection();
        
        if ([JSON isKindOfClass:[NSArray class]] && ([JSON count] == 1))
        {
            NSDictionary *responseDict = [JSON objectAtIndex:0];
            if ([responseDict objectForKey:@"version"])
            {
                NSArray *versionComponents = [[responseDict objectForKey:@"version"] componentsSeparatedByString:@"-"];
                if ([versionComponents count] == 2)
                {
                    timeoutDuration = 10*60; // 10 minutes timeout
                    protocolVersion = [[versionComponents objectAtIndex:1] intValue];
                    [self dsmVersion];
                    NSLog(@"DSM %f, protocolVersion = %ld",dsmVersion, (long)protocolVersion);
                }
            }
            
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    nil]];
        });
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        // We are no able to get protocol version, but we still try to continue
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    nil]];
        });
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:@"webman/modules/status.cgi"]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}

- (void)dsmVersion
{
    if (protocolVersion > 0)
    {
        /* DSM version list :
         * DSM2.0 : 0722 - 0732 (0722,0731,0732)
         * DSM2.1 : 0832 - 0851 (0832,0844,0851)
         * DSM2.2 : 0942 - 1045 (0942,0947,0959,0965,1041,1042,1045)
         * DSM2.3 : 1139 - 1167 (1139,1141,1144,1149,1157,1161,1167)
         * DSM3.0 : 1337 - 1372 (1337,1340,1342,1354,1358,1372)
         * DSM3.1 : 1594 - 1760 (1594,1605,1613,1632,1635,1636,1742,1746,1748,1752,1760)
         * DSM3.2 : 1922 - 2031 (1922,1944,1947,1955,1958,1960,1963,1968,2031)
         * DSM4.0 : 2198 - 2454 (2198,2219,2228,2233,2243,2245,2254,2454)
         * DSM4.1 : 2636 - 2851 (2636,2647,2650,2657,2661,2668,2842,2846,2850,2851)
         * DSM4.2 : 3202 - 3320 (3202,3211,3214,3227,3233,3234,3235,3236,3243,3246,3320)
         * DSM4.3 : 3776 - 3827 (3776,3781,3803,3805,3810,3827)
         * DSM5.0 : 4458 - ?
         * DSM5.1 : 5004 - ?
         */
        /* DSM beta versions (may not work correctly)
         * DSM3.1 beta : 1553
         * DSM3.2 beta : 1869
         * DSM4.0 beta : 2166
         * DSM4.1 beta : 2567
         * DSM4.2 beta : 3160
         * DSM4.3 beta : 3750
         * DSM5.0 beta : 4418
         * DSM5.1 beta : 4977
         */
        if (protocolVersion >= 4977)
        {
            dsmVersion = SYNOLOGY_DSM_5_1;
        }
        else if (protocolVersion >= 4418)
        {
            dsmVersion = SYNOLOGY_DSM_5_0;
        }
        else if (protocolVersion >= 3750)
        {
            dsmVersion = SYNOLOGY_DSM_4_3;
        }
        else if (protocolVersion >= 3160)
        {
            dsmVersion = SYNOLOGY_DSM_4_2;
        }
        else if (protocolVersion >= 2567)
        {
            dsmVersion = SYNOLOGY_DSM_4_1;
        }
        else if (protocolVersion >= 2166)
        {
            dsmVersion = SYNOLOGY_DSM_4_0;
        }
        else if (protocolVersion >= 1869)
        {
            dsmVersion = SYNOLOGY_DSM_3_2;
        }
        else if (protocolVersion >= 1553)
        {
            dsmVersion = SYNOLOGY_DSM_3_1;
        }
        else if (protocolVersion >= 1337)
        {
            dsmVersion = SYNOLOGY_DSM_3_0;
        }
        else if (protocolVersion >= 1139)
        {
            dsmVersion = SYNOLOGY_DSM_2_3;
        }
        else if (protocolVersion >= 942)
        {
            dsmVersion = SYNOLOGY_DSM_2_2;
        }
        else if (protocolVersion >= 832)
        {
            dsmVersion = SYNOLOGY_DSM_2_1;
        }
        else if (protocolVersion >= 722)
        {
            dsmVersion = SYNOLOGY_DSM_2_0;
        }
    }
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

- (NSString *)escapeSynoString:(NSString *)inputString
{
    return [inputString stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
}
@end
