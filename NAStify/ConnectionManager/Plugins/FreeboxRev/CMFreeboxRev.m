//
//  CMFreeboxRev.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//
//  Interface documentation : http://mafreebox.fr/doc/fs.html or
//  http://mafreebox.freebox.fr/doc/fs.html if you have a freebox revolution
//
//  Documentation is explaining how to extract archives with password
//  but it's not working on the server side for now.
//
//  TODO : handle connection timeout correctly
//  TODO : delete created shared links when not needed anymore
//

#import "CMFreeboxRev.h"
#import "SBNetworkActivityIndicator.h"
#import "NSStringAdditions.h"
#import "NSDataAdditions.h"
#import "SSKeychain.h"

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>

@interface CMFreeboxRev (Private)
- (NSString *)bundleName;
#ifndef APP_EXTENSION
- (void)getToken;
- (void)actionGetTokenProgress;
#endif
- (void)actionOpenSession;

- (BOOL)isCompressed:(NSString *)type;
#ifndef APP_EXTENSION
- (void)deleteProgress;
- (void)copyProgress;
- (void)moveProgress;
- (void)renameProgress;
- (void)extractProgress;
- (void)compressProgress;
- (void)ejectableList;
#endif

- (void)deleteUploadTask:(NSInteger)taskID;
- (void)cleanUploadTasks;
- (void)finishRequest;
- (void)HandleRequestFailure:(NSError *)error withJSON:(id)JSON showAlert:(BOOL)showAlert;
- (void)deleteTask:(NSInteger)taskID;

- (void)serverData;
#ifndef APP_EXTENSION
- (void)connectionInfo;
#endif
@end

@implementation CMFreeboxRev

- (id)init
{
    self = [super init];
    if (self)
    {
        self.manager = [AFHTTPRequestOperationManager manager];
        self.manager.requestSerializer = [AFJSONRequestSerializer serializer];
        [self.manager.requestSerializer setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        self.manager.responseSerializer = [AFJSONResponseSerializer serializer];
        
        [self.manager.reachabilityManager startMonitoring];
    }
    return self;
}

- (void)HandleRequestFailure:(NSError *)error withJSON:(id)JSON showAlert:(BOOL)showAlert
{
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    
    if (([JSON objectForKey:@"success"]) && ([[JSON objectForKey:@"success"] boolValue] == NO))
    {
        if ([[JSON objectForKey:@"error_code"] isEqualToString:@"auth_required"])
        {
            if (showAlert)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMAction:[NSDictionary dictionaryWithObjectsAndKeys:
                                             NSLocalizedString(@"Error",nil),@"title",
                                             NSLocalizedString(@"Not connected, trying to connect",nil),@"message",
                                             [NSNumber numberWithInteger:BROWSER_ACTION_DO_NOTHING],@"action",
                                             nil]];
                });
            }
            
            // Try to login
            self.sessionChallenge = [[JSON objectForKey:@"result"] objectForKey:@"challenge"];
            [self actionOpenSession];
        }
        else
        {
            if (showAlert)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMAction:[NSDictionary dictionaryWithObjectsAndKeys:
                                             NSLocalizedString(@"Error",nil),@"title",
                                             NSLocalizedString([JSON objectForKey:@"msg"],nil),@"message",
                                             [NSNumber numberWithInteger:BROWSER_ACTION_DO_NOTHING],@"action",
                                             nil]];
                });
            }
        }
    }
    else if (JSON == nil)
    {
        if (showAlert)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMAction:[NSDictionary dictionaryWithObjectsAndKeys:
                                         NSLocalizedString(@"Error",nil),@"title",
                                         [error localizedDescription],@"message",
                                         [NSNumber numberWithInteger:BROWSER_ACTION_DO_NOTHING],@"action",
                                         nil]];
            });
        }
    }
}

- (NSString *)createUrlWithPath:(NSString *)path
{
    return [NSString stringWithFormat:@"http://%@:%@/%@", self.userAccount.server, self.userAccount.port, path];
}

#pragma mark - Server Info

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           [NSString stringWithFormat:NSLocalizedString(@"Server Model : Freebox Revolution (%@)",nil),serverHwModel],
                           [NSString stringWithFormat:NSLocalizedString(@"Firmware : %@",nil), serverFirmware],
                           [NSString stringWithFormat:NSLocalizedString(@"Serial : %@",nil), serverSerial],
                           [NSString stringWithFormat:NSLocalizedString(@"MAC : %@",nil), serverMAC],
                           nil];
    return serverInfo;
}

#pragma mark - token management

#ifndef APP_EXTENSION
- (void)getToken
{
    if (self.manager.reachabilityManager.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi)
    {
        [self.delegate CMAction:[NSDictionary dictionaryWithObjectsAndKeys:
                                 NSLocalizedString(@"Information",nil),@"title",
                                 NSLocalizedString(@"Please accept the pairing request on Freebox's screen",nil),@"message",
                                 [NSNumber numberWithInteger:BROWSER_ACTION_DO_NOTHING],@"action",
                                 nil]];

        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            if ([[JSON objectForKey:@"success"] boolValue] == YES)
            {
                self.tempToken = [[JSON objectForKey:@"result"] objectForKey:@"app_token"];
                self.trackID = [[JSON objectForKey:@"result"] objectForKey:@"track_id"];
                [self performSelector:@selector(actionGetTokenProgress) withObject:nil afterDelay:2];
            }
            
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        NSLocalizedString(@"You have to be connected to the wifi network of your Freebox to perform pairing",nil),@"error",
                                            nil]];
            });
        };
        
        NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:[self bundleName],@"app_id",
                                [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"],@"app_name",
                                [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],@"app_version",
                                [[UIDevice currentDevice] name],@"device_name",
                                nil];
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:@"api/v3/login/authorize/"]
                parameters:params
                   success:successBlock
                   failure:failureBlock];
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO],@"success",
                                    NSLocalizedString(@"You have to be connected to the wifi network of your Freebox to perform pairing",nil),@"error",
                                    nil]];
        });
    }
}
#endif

#ifndef APP_EXTENSION
- (void)actionGetTokenProgress
{
    if (self.trackID != nil)
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            if ([[JSON objectForKey:@"success"] boolValue] == YES)
            {
                NSString *status = [[JSON objectForKey:@"result"] objectForKey:@"status"];
                if ([status isEqualToString:@"pending"])
                {
                    [self performSelector:@selector(actionGetTokenProgress) withObject:nil afterDelay:2];
                }
                else if ([status isEqualToString:@"timeout"])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                NSLocalizedString(@"Token Request : Timeout",nil),@"error",
                                                nil]];
                    });
                }
                else if ([status isEqualToString:@"granted"])
                {
                    [SSKeychain setPassword:self.tempToken
                                 forService:self.userAccount.uuid
                                    account:@"token"];

                    /* Save updated information */
                    NSNotification* notification = [NSNotification notificationWithName:@"UPDATEACCOUNT"
                                                                                 object:self
                                                                               userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                         self.userAccount,@"account",
                                                                                         nil]];
                    
                    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:)
                                                                           withObject:notification waitUntilDone:YES];

                    /* Perform login */
                    [self login];
                }
                else if ([status isEqualToString:@"denied"])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                NSLocalizedString(@"Token Request : Denied",nil),@"error",
                                                nil]];
                    });
                }
                else if ([status isEqualToString:@"unknown"])
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                NSLocalizedString(@"Token Request : Invalid",nil),@"error",
                                                nil]];
                    });
                }
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        };
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"api/v3/login/authorize/%@",self.trackID]]
               parameters:nil
                  success:successBlock
                  failure:failureBlock];
    }
}
#endif

#pragma mark - login/logout management

- (BOOL)login
{
    if ([SSKeychain passwordForService:self.userAccount.uuid account:@"token"])
    {
        // Perform login
        
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            if ([[JSON objectForKey:@"success"] boolValue] == YES)
            {
                self.sessionChallenge = [[JSON objectForKey:@"result"] objectForKey:@"challenge"];
                [self actionOpenSession];
            }
            else
            {
                // Should not happen
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            NSLocalizedString(@"Unknown error",nil),@"error",
                                            nil]];
                });
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            [self HandleRequestFailure:error
                              withJSON:operation.responseObject
                             showAlert:YES];
        };
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

        [self.manager GET:[self createUrlWithPath:@"api/v3/login/"]
               parameters:nil
                  success:successBlock
                  failure:failureBlock];
    }
    else
    {
#ifndef APP_EXTENSION
        // Get token
        [self getToken];
#else
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMAction:[NSDictionary dictionaryWithObjectsAndKeys:
                                     NSLocalizedString(@"Error",nil),@"title",
                                     NSLocalizedString(@"You shall connect to this server one time with main application (to get token) before using the extension",nil),@"message",
                                     [NSNumber numberWithInteger:BROWSER_ACTION_QUIT_SERVER],@"action",
                                     nil]];
        });
#endif
    }
    
    return YES;
}

- (void)actionOpenSession
{
	unsigned char cHMAC[CC_SHA1_DIGEST_LENGTH];
    
    const char *cKey  = [[SSKeychain passwordForService:self.userAccount.uuid account:@"token"] cStringUsingEncoding:NSASCIIStringEncoding];
	const char *cData = [self.sessionChallenge cStringUsingEncoding:NSASCIIStringEncoding];
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            self.sessionToken = [[JSON objectForKey:@"result"] objectForKey:@"session_token"];
            
            [self.manager.requestSerializer setValue:self.sessionToken forHTTPHeaderField:@"X-Fbx-App-Auth"];
            [self.manager.requestSerializer setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            
            [self serverData];
#ifndef APP_EXTENSION
            if ([self.userAccount.server isEqualToString:@"mafreebox.freebox.fr"])
            {
                // If we are connected, we are checking if we can get public IP and port info to replace them in
                // the server settings
                [self connectionInfo];
            }
            else
#endif
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:YES],@"success",
                                            nil]];
                });
            }
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        [JSON objectForKey:@"msg"],@"error",
                                        nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        NSString *errorMsg = nil;
        NSDictionary *JSON = operation.responseObject;
        if (([JSON objectForKey:@"success"]) && ([[JSON objectForKey:@"success"] boolValue] == NO))
        {
            errorMsg = [JSON objectForKey:@"msg"];
        }
        else if (JSON == nil)
        {
            errorMsg = [error localizedDescription];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO],@"success",
                                    errorMsg,@"error",
                                    nil]];
        });
    };
    
	CCHmac(kCCHmacAlgSHA1, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
	
	NSData *HMAC = [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    NSString *hexRepresentation = [HMAC hexRepresentationWithSpaces_AS:NO];
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            [self bundleName],@"app_id",
                            hexRepresentation,@"password",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"api/v3/login/session/"]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

- (BOOL)logout
{
    if ([SSKeychain passwordForService:self.userAccount.uuid account:@"token"])
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            [self.manager.operationQueue cancelAllOperations];
            
            self.sessionToken = nil;
            
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
        
        deleteTaskID = -1;
        copyTaskID = -1;
        moveTaskID = -1;
        extractTaskID = -1;
        compressTaskID = -1;
        
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [self.manager POST:[self createUrlWithPath:@"api/v3/login/logout/"]
                parameters:nil
                   success:successBlock
                   failure:failureBlock];
    }
    [self.manager.operationQueue cancelAllOperations];
    return YES;
}

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            NSMutableArray *filesOutputArray = nil;
            /* Build dictionary with items */
            NSArray *filesInputArray = [JSON objectForKey:@"result"];
            filesOutputArray = [NSMutableArray arrayWithCapacity:[filesInputArray count]];
            for (NSDictionary *fileItem in filesInputArray)
            {
                if ((![[fileItem objectForKey:@"name"] isEqualToString:@"."]) &&
                    (![[fileItem objectForKey:@"name"] isEqualToString:@".."]))
                {
                    NSString *type = @"";
                    if ([[[fileItem objectForKey:@"name"] componentsSeparatedByString:@"."] count] > 1)
                        type = [[[fileItem objectForKey:@"name"] componentsSeparatedByString:@"."] lastObject];
                    NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [[fileItem objectForKey:@"type"] isEqualToString:@"dir"]?@"1":@"0",@"isdir",
                                              [fileItem objectForKey:@"name"],@"filename",
                                              [NSString stringForSize:[[fileItem objectForKey:@"size"] longLongValue]],@"filesize",
                                              [NSNumber numberWithLongLong:[[fileItem objectForKey:@"size"] longLongValue]],@"filesizenumber",
                                              @"",@"group",
                                              @"",@"owner",
                                              [NSNumber numberWithBool:[self isCompressed:type]],@"iscompressed",
                                              [NSNumber numberWithBool:YES],@"writeaccess",
                                              [fileItem objectForKey:@"modification"],@"date",
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
            
#ifndef APP_EXTENSION
            if ([folder.path isEqualToString:@"/"])
            {
                [self ejectableList];
            }
#endif
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            folder.path,@"path",
                                            [JSON objectForKey:@"msg"],@"error",
                                            nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
    };
    
    NSData *base64Data = [[folder.path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
    NSString *base64path = [[[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding] encodeString:NSUTF8StringEncoding];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat: @"api/v3/fs/ls/%@?countSubFolder=0&removehidden=1",base64path]]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}

#pragma mark - space info management

- (void)spaceInfoAtPath:(FileItem *)folder
{
    if (![folder.path isEqualToString:@"/"])
    {
        void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
            // End the network activity spinner
            [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
            
            if ([[JSON objectForKey:@"success"] boolValue] == YES)
            {
                // The answer contains values for each disk, we have to find the one we want
                NSInteger currentDiskIndex = 0;
                for (currentDiskIndex = 0; currentDiskIndex < [[JSON objectForKey:@"result"] count];currentDiskIndex++)
                {
                    NSDictionary *diskInfo = [[JSON objectForKey:@"result"] objectAtIndex:currentDiskIndex];
                    
                    // First Element is "/", we have to take second element to get root folder
                    NSString *currentLabel = [[folder.path pathComponents] objectAtIndex:1];
                    if ([currentLabel isEqualToString:[diskInfo objectForKey:@"label"]])
                    {
                        // Good info found
                        break;
                    }
                }
                NSDictionary *dict = [[JSON objectForKey:@"result"] objectAtIndex:currentDiskIndex];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMSpaceInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                [dict objectForKey:@"total_bytes"],@"totalspace",
                                                [dict objectForKey:@"free_bytes"],@"freespace",
                                                nil]];
                });
            }
            else
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMSpaceInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:NO],@"success",
                                                [JSON objectForKey:@"msg"],@"error",
                                                nil]];
                });
            }
        };
        
        void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
            [self HandleRequestFailure:error
                              withJSON:operation.responseObject
                             showAlert:NO];
        };
        
        NSURL *baseUrl = [NSURL URLWithString:[self createUrlWithPath:@"api/v3/storage/partition/?page=1&start=0&limit=25"]];
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:baseUrl];
        
        [request setValue:self.sessionToken forHTTPHeaderField:@"X-Fbx-App-Auth"];
        
        AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc]
                                             initWithRequest:request];
        
        operation.responseSerializer = [AFJSONResponseSerializer serializer];
        
        [operation setCompletionBlockWithSuccess:successBlock
                                         failure:failureBlock];
        
#ifndef APP_EXTENSION
        [operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];
#else
        [operation start];
#endif
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
        
        [operation start];
    }
}

#pragma mark - Folder creation management

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
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
                                               [JSON objectForKey:@"msg"],@"error",
                                               nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
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
    
    NSData *base64Data = [[folder.path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
    NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            base64path,@"parent",
                            folderName,@"dirname",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"api/v3/fs/mkdir/"]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

#pragma mark - delete management

#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            deleteTaskID = [[[JSON objectForKey:@"result"] objectForKey:@"id"] integerValue];
            [self deleteProgress];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [[JSON objectForKey:@"error"] objectForKey:@"message"],@"error",
                                                 nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
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
    
    NSMutableArray *filesArray = [NSMutableArray arrayWithCapacity:[files count]];
    for (FileItem *file in files)
    {
        NSData *base64Data = [[file.path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
        NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
        [filesArray addObject:base64path];
    }
    
    NSDictionary *params = [NSDictionary dictionaryWithObject:filesArray forKey:@"files"];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"api/v3/fs/rm/"]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

- (void)deleteProgress
{
    if (deleteTaskID == -1)
    {
        return;
    }
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            NSDictionary *element = [JSON objectForKey:@"result"];
            if ([[element objectForKey:@"state"] isEqualToString:@"running"])
            {
                float progress = [[element objectForKey:@"progress"] floatValue] / 100;
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithFloat:progress],@"progress",
                                                 nil];
                
                if ([[element objectForKey:@"nfiles"] integerValue] != 0)
                {
                    NSString *infos = [NSString stringWithFormat:@"(%ld/%@) : %@",
                                       (long)([[element objectForKey:@"nfiles_done"] integerValue] + 1),
                                       [element objectForKey:@"nfiles"],[[element objectForKey:@"from"] lastPathComponent]];;
                    [dict addEntriesFromDictionary:[NSDictionary dictionaryWithObject:infos
                                                                                   forKey:@"info"]];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteProgress:dict];
                });

                [self performSelector:@selector(deleteProgress)
                           withObject:nil
                           afterDelay:2];
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"done"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:YES],@"success",
                                                     nil]];
                });
                
                [self deleteTask:deleteTaskID];
                deleteTaskID = -1;
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"paused"])
            {
                deleteTaskID = -1;
                // Stop updating info
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     NSLocalizedString(@"Pause not supported",nil),@"error",
                                                     nil]];
                });
                
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"failed"])
            {
                // Stop updating info
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithBool:NO],@"success",
                                                     NSLocalizedString([element objectForKey:@"error"], nil),@"error",
                                                     nil]];
                });

                [self deleteTask:deleteTaskID];
                deleteTaskID = -1;
            }
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [JSON objectForKey:@"msg"],@"error",
                                                 nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
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
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"api/v3/fs/tasks/%ld",(long)deleteTaskID]]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}

- (void)cancelDeleteTask
{
    [self deleteTask:deleteTaskID];
    deleteTaskID = -1;
}
#endif

#pragma mark - copy management

#ifndef APP_EXTENSION
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            copyTaskID = [[[JSON objectForKey:@"result"] objectForKey:@"id"] integerValue];
            [self copyProgress];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [JSON objectForKey:@"msg"],@"error",
                                               nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
        {
            errorMessage = [error localizedDescription];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           errorMessage,@"error",
                                           nil]];
        });
    };
    
    NSMutableArray *filesArray = [NSMutableArray arrayWithCapacity:[files count]];
    for (FileItem *file in files)
    {
        NSData *base64Data = [[file.path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
        NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
        [filesArray addObject:base64path];
    }

    NSData *base64Data = [[destFolder.path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
    NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            filesArray,@"files",
                            base64path,@"dst",
                            overwrite?@"overwrite":@"skip",@"mode",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"api/v3/fs/cp/"]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

- (void)copyProgress
{
    if (copyTaskID == -1)
    {
        return;
    }
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            NSDictionary *element = [JSON objectForKey:@"result"];
            if ([[element objectForKey:@"state"] isEqualToString:@"running"])
            {
                float progress = [[element objectForKey:@"progress"] floatValue] / 100;
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithFloat:progress],@"progress",
                                             nil];
                
                if ([[element objectForKey:@"nfiles"] integerValue] != 0)
                {
                    NSString *infos = [NSString stringWithFormat:@"(%ld/%@) : %@",
                                       // +1 To have the current proccessed file instead of number of already processed files
                                       (long)([[element objectForKey:@"nfiles_done"] integerValue] + 1),
                                       [element objectForKey:@"nfiles"],[[element objectForKey:@"from"] lastPathComponent]];;
                    [dict addEntriesFromDictionary:[NSDictionary dictionaryWithObject:infos
                                                                               forKey:@"info"]];
                }

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCopyProgress:dict];
                });

                [self performSelector:@selector(copyProgress) withObject:nil afterDelay:2];
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"done"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES],@"success",
                                                   nil]];
                });
                
                [self deleteTask:copyTaskID];
                copyTaskID = -1;
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"paused"])
            {
                copyTaskID = -1;
                // Stop updating info
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   NSLocalizedString(@"Pause not supported",nil),@"error",
                                                   nil]];
                });
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"failed"])
            {
                // Stop updating info
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   NSLocalizedString([element objectForKey:@"error"], nil),@"error",
                                                   nil]];
                });
                
                [self deleteTask:copyTaskID];
                copyTaskID = -1;
            }
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [JSON objectForKey:@"msg"],@"error",
                                               nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
        {
            errorMessage = [error localizedDescription];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithBool:NO],@"success",
                                           errorMessage,@"error",
                                           nil]];
        });
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"api/v3/fs/tasks/%ld",(long)copyTaskID]]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}

- (void)cancelCopyTask
{
    [self deleteTask:copyTaskID];
    copyTaskID = -1;
}
#endif

#pragma mark - move management

#ifndef APP_EXTENSION
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            moveTaskID = [[[JSON objectForKey:@"result"] objectForKey:@"id"] integerValue];
            [self moveProgress];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [JSON objectForKey:@"msg"],@"error",
                                               nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
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
    
    NSMutableArray *filesArray = [NSMutableArray arrayWithCapacity:[files count]];
    for (FileItem *file in files)
    {
        NSData *base64Data = [[file.path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
        NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
        [filesArray addObject:base64path];
    }
    
    NSData *base64Data = [[destFolder.path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
    NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            filesArray,@"files",
                            base64path,@"dst",
                            overwrite?@"overwrite":@"skip",@"mode",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"api/v3/fs/mv/"]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

- (void)moveProgress
{
    if (moveTaskID == -1)
    {
        return;
    }
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            NSDictionary *element = [JSON objectForKey:@"result"];
            if ([[element objectForKey:@"state"] isEqualToString:@"running"])
            {
                float progress = [[element objectForKey:@"progress"] floatValue] / 100;
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithFloat:progress],@"progress",
                                             nil];
                
                if ([[element objectForKey:@"nfiles"] integerValue] != 0)
                {
                    NSString *infos = [NSString stringWithFormat:@"(%ld/%@) : %@",
                                       // +1 To have the current proccessed file instead of number of already processed files
                                       (long)([[element objectForKey:@"nfiles_done"] integerValue] + 1),
                                       [element objectForKey:@"nfiles"],[[element objectForKey:@"from"] lastPathComponent]];;
                    [dict addEntriesFromDictionary:[NSDictionary dictionaryWithObject:infos
                                                                               forKey:@"info"]];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveProgress:dict];
                });

                [self performSelector:@selector(moveProgress) withObject:nil afterDelay:2];
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"done"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES],@"success",
                                                   nil]];
                });
                
                [self deleteTask:moveTaskID];
                moveTaskID = -1;
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"paused"])
            {
                moveTaskID = -1;
                // Stop updating info
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   NSLocalizedString(@"Pause not supported",nil),@"error",
                                                   nil]];
                });
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"failed"])
            {
                // Stop updating info
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   NSLocalizedString([element objectForKey:@"error"], nil),@"error",
                                                   nil]];
                });
                
                [self deleteTask:moveTaskID];
                moveTaskID = -1;
            }
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [JSON objectForKey:@"msg"],@"error",
                                               nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
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
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"api/v3/fs/tasks/%ld",(long)moveTaskID]]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}

- (void)cancelMoveTask
{
    [self deleteTask:moveTaskID];
    moveTaskID = -1;
}
#endif

#pragma mark - Renaming management

#ifndef APP_EXTENSION
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
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
                                         [JSON objectForKey:@"msg"],@"error",
                                         nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
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
    
    NSData *base64Data = [[[NSString stringWithFormat:@"%@/%@",folder.path,oldFile.name] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
    NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            base64path,@"src",
                            newName,@"dst",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"api/v3/fs/rename/"]
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
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            extractTaskID = [[[JSON objectForKey:@"result"] objectForKey:@"id"] integerValue];
            [self extractProgress];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:NO],@"success",
                                                  [JSON objectForKey:@"msg"],@"error",
                                                  nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
        {
            errorMessage = [error localizedDescription];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithBool:NO],@"success",
                                              errorMessage,@"error",
                                              nil]];
        });
    };
    
    FileItem *fileItem = [files firstObject];
    
    NSData *base64SrcData = [[fileItem.path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
    NSData *base64DstData = [[folder.path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            [[NSString alloc] initWithData:base64SrcData encoding:NSUTF8StringEncoding],@"src",
                            [[NSString alloc] initWithData:base64DstData encoding:NSUTF8StringEncoding],@"dst",
                            password?password:@"",@"password",
                            [NSNumber numberWithBool:NO],@"delete_archive",
                            [NSNumber numberWithBool:overwrite],@"overwrite",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"api/v3/fs/extract/"]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

- (void)extractProgress
{
    if (extractTaskID == -1)
    {
        return;
    }
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            NSDictionary *element = [JSON objectForKey:@"result"];
            if ([[element objectForKey:@"state"] isEqualToString:@"running"])
            {
                float progress = [[element objectForKey:@"progress"] floatValue] / 100;
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithFloat:progress],@"progress",
                                             nil];
                
                if ([[element objectForKey:@"nfiles"] integerValue] != 0)
                {
                    NSString *infos = [NSString stringWithFormat:@"(%ld/%@) : %@",
                                       // +1 To have the current proccessed file instead of number of already processed files
                                       (long)([[element objectForKey:@"nfiles_done"] integerValue] + 1),
                                       [element objectForKey:@"nfiles"],[[element objectForKey:@"to"] lastPathComponent]];;
                    [dict addEntriesFromDictionary:[NSDictionary dictionaryWithObject:infos
                                                                               forKey:@"info"]];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractProgress:dict];
                });
                [self performSelector:@selector(extractProgress) withObject:nil afterDelay:2];
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"done"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:YES],@"success",
                                                      nil]];
                });
                [self deleteTask:extractTaskID];
                extractTaskID = -1;
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"paused"])
            {
                extractTaskID = -1;
                // Stop updating info
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:NO],@"success",
                                                      NSLocalizedString(@"Pause not supported",nil),@"error",
                                                      nil]];
                });
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"failed"])
            {
                // Stop updating info
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:NO],@"success",
                                                      NSLocalizedString([element objectForKey:@"error"], nil),@"error",
                                                      nil]];
                });
                
                [self deleteTask:extractTaskID];
                extractTaskID = -1;
            }
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:NO],@"success",
                                                  [JSON objectForKey:@"msg"],@"error",
                                                  nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
        {
            errorMessage = [error localizedDescription];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithBool:NO],@"success",
                                              error,@"error",
                                              nil]];
        });
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"api/v3/fs/tasks/%ld",(long)extractTaskID]]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}

- (void)cancelExtractTask
{
    [self deleteTask:extractTaskID];
    extractTaskID = -1;
}
#endif

#pragma mark - Compress management

#ifndef APP_EXTENSION
- (void)compressFiles:(NSArray *)files
            toArchive:(NSString *)archive
          archiveType:(ARCHIVE_TYPE)archiveType // unused
     compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel // unused
             password:(NSString *)password
            overwrite:(BOOL)overwrite // unused
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            compressTaskID = [[[JSON objectForKey:@"result"] objectForKey:@"id"] integerValue];
            [self compressProgress];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [JSON objectForKey:@"msg"],@"error",
                                                   nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
        {
            errorMessage = [error localizedDescription];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               errorMessage,@"error",
                                               nil]];
        });
    };
    
    NSMutableArray *filesArray = [NSMutableArray arrayWithCapacity:[files count]];
    for (FileItem *file in files)
    {
        NSData *base64Data = [[file.path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
        NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
        [filesArray addObject:base64path];
    }
    
    NSData *base64Data = [[archive dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
    NSString *base64archive = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];

    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            filesArray,@"files",
                            base64archive,@"dst",
                            nil];
   
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"api/v3/fs/archive/"]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

- (void)compressProgress
{
    if (compressTaskID == -1)
    {
        return;
    }
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            NSDictionary *element = [JSON objectForKey:@"result"];
            if ([[element objectForKey:@"state"] isEqualToString:@"running"])
            {
                float progress = [[element objectForKey:@"progress"] floatValue] / 100;
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithFloat:progress],@"progress",
                                             nil];
                
                if ([[element objectForKey:@"nfiles"] integerValue] != 0)
                {
                    NSString *infos = [NSString stringWithFormat:@"(%ld/%@) : %@",
                                       // +1 To have the current proccessed file instead of number of already processed files
                                       (long)([[element objectForKey:@"nfiles_done"] integerValue] + 1),
                                       [element objectForKey:@"nfiles"],[[element objectForKey:@"from"] lastPathComponent]];;
                    [dict addEntriesFromDictionary:[NSDictionary dictionaryWithObject:infos
                                                                               forKey:@"info"]];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressProgress:dict];
                });

                [self performSelector:@selector(compressProgress) withObject:nil afterDelay:2];
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"done"])
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:YES],@"success",
                                                       nil]];
                });
                
                [self deleteTask:compressTaskID];
                compressTaskID = -1;
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"paused"])
            {
                compressTaskID = -1;
                // Stop updating info
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       NSLocalizedString(@"Pause not supported", nil),@"error",
                                                       nil]];
                });
            }
            else if ([[element objectForKey:@"state"] isEqualToString:@"failed"])
            {
                // Stop updating info
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithBool:NO],@"success",
                                                       [element objectForKey:@"error"],@"error",
                                                       nil]];
                });

                [self deleteTask:compressTaskID];
                compressTaskID = -1;
            }
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [JSON objectForKey:@"msg"],@"error",
                                                   nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
        {
            errorMessage = [error localizedDescription];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               errorMessage,@"error",
                                               nil]];
        });
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"api/v3/fs/tasks/%ld",(long)compressTaskID]]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}

- (void)cancelCompressTask
{
    [self deleteTask:compressTaskID];
    compressTaskID = -1;
}
#endif

#pragma mark - Eject management

#ifndef APP_EXTENSION
- (void)ejectableList
{
    // Warning : Storage API is marked as unstable, it may change on the server side
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            NSMutableArray *devicesArray = [NSMutableArray array];

            // The answer contains values for each disk
            for (NSDictionary *diskInfo in [JSON objectForKey:@"result"])
            {
                if ([[diskInfo objectForKey:@"type"] isEqualToString:@"usb"])
                {
                    for (NSDictionary *partitionInfo in [diskInfo objectForKey:@"partitions"])
                    {
                        NSString *folder = [partitionInfo objectForKey:@"label"];
                        NSString *ejectableName = [partitionInfo objectForKey:@"id"];
                        NSDictionary *deviceElement = [NSDictionary dictionaryWithObjectsAndKeys:
                                                       folder,@"folder",
                                                       ejectableName,@"ejectname",
                                                       nil];
                        
                        [devicesArray addObject:deviceElement];
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
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:@"api/v3/storage/disk/"]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}

- (void)ejectFile:(FileItem *)fileItem
{
    // Warning : Storage API is marked as unstable, it may change on the server side
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
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
                                                [JSON objectForKey:@"msg"],@"error",
                                                nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];

        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            if ([[operation.responseObject objectForKey:@"error_code"] isEqualToString:@"insufficient_rights"])
            {
                errorMessage = [NSString stringWithFormat:@"%@, please add \"%@\" right to the app",
                                [operation.responseObject objectForKey:@"msg"],
                                [operation.responseObject objectForKey:@"missing_right"]];
            }
            else
            {
                errorMessage = [operation.responseObject objectForKey:@"msg"];
            }
        }
        else
        {
            errorMessage = [error localizedDescription];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMEjectFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            errorMessage,@"error",
                                            nil]];
        });
    };
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"umounted",@"state",
                            nil];

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager PUT:[self createUrlWithPath:[NSString stringWithFormat:@"api/v3/storage/partition/%@",fileItem.ejectName]]
           parameters:params
              success:successBlock
              failure:failureBlock];
}
#endif

#pragma mark - Sharing management

#ifndef APP_EXTENSION
- (void)shareFile:(FileItem *)file duration:(NSTimeInterval)duration password:(NSString *)password
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            [self.sharedLinks appendFormat:@"%@ : %@\r\n",file.name,[[JSON objectForKey:@"result"] objectForKey:@"fullurl"]];
        }
        else
        {
            [self.sharedLinks appendFormat:@"%@ : Failed\r\n",file.name];
        }

        // Share next item if needed
        [self.sharedFiles removeObjectAtIndex:0];
        if (self.sharedFiles.count > 0)
        {
            [self shareFile:[self.sharedFiles objectAtIndex:0]
                   duration:self.sharedInterval
                   password:self.sharedPassword];
        }
        else
        {
            [self.sharedLinks appendString:NSLocalizedString(@"Shared using NAStify\r\n",nil)];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                self.sharedLinks,@"shares",
                                                nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
        {
            errorMessage = [error localizedDescription];
        }
        
        [self.sharedLinks appendFormat:@"%@ : %@\r\n",file.name,errorMessage];
        
        // Share next item if needed
        [self.sharedFiles removeObjectAtIndex:0];
        if (self.sharedFiles.count > 0)
        {
            [self shareFile:[self.sharedFiles objectAtIndex:0]
                   duration:self.sharedInterval
                   password:self.sharedPassword];
        }
        else
        {
            [self.sharedLinks appendString:NSLocalizedString(@"Shared using NAStify\r\n",nil)];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMShareFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES],@"success",
                                                self.sharedLinks,@"shares",
                                                nil]];
            });
        }
    };
    
    // Set sharing duration to 5 hours
    NSDate *expiredate = [NSDate dateWithTimeIntervalSinceNow:duration];
    
    NSTimeInterval interval = 0;
    if (duration != 0)
    {
        interval = [expiredate timeIntervalSince1970];
    }
    
    NSData *base64Data = [[file.fullPath dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
    NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            base64path,@"path",
                            [NSNumber numberWithInteger:(NSInteger)interval],@"expire",
                            @"",@"fullurl",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"api/v3/share_link/"]
            parameters:params
               success:successBlock
               failure:failureBlock];
}


- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password
{
    self.sharedLinks = [[NSMutableString alloc] init];
    self.sharedFiles = [NSMutableArray arrayWithArray:files];
    self.sharedPassword = password;
    self.sharedInterval = duration;
    
    [self shareFile:[self.sharedFiles objectAtIndex:0]
           duration:self.sharedInterval
           password:self.sharedPassword];
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
        
        if (!operation.isCancelled)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [error description],@"error",
                                                   nil]];
            });
        }
    };
    
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    NSData *base64Data = [[file.fullPath dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
    NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];

    downloadOperation = [self.manager GET:[self createUrlWithPath:[NSString stringWithFormat:@"api/v3/dl/%@?inline=0",base64path]]
                               parameters:nil
                                  success:successBlock
                                  failure:failureBlock];
    
    downloadOperation.outputStream = [NSOutputStream outputStreamToFileAtPath:localName append:NO];
    
    __block long long lastNotifiedProgress = 0;
    [downloadOperation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        // Call delegate every 0,5% of progress (to limit the impact on performances)
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
    
    [downloadOperation start];
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
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            uploadTaskID = [[[JSON objectForKey:@"result"] objectForKey:@"id"] integerValue];
            [self uploadLocalFile:file.fullPath];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [JSON objectForKey:@"msg"],@"error",
                                                 nil]];
            });
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
        {
            errorMessage = [error localizedDescription];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:NO],@"success",
                                             errorMessage,@"error",
                                             nil]];
        });
    };
    
    NSData *base64Data = [[destFolder.path dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
    NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            base64path,@"dirname",
                            file.name,@"upload_name",
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"api/v3/upload/"]
            parameters:params
               success:successBlock
               failure:failureBlock];
}

- (void)cancelUploadTask
{
    // Cancel request
    [self deleteUploadTask:uploadTaskID];
    
    [uploadOperation cancel];
}

- (void)uploadLocalFile:(NSString *)localPath
{
    __weak typeof(self) weakSelf = self;
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
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
                                                 [JSON objectForKey:@"msg"],@"error",
                                                 nil]];
            });
        }
        // Clean finished upload task
        [self cleanUploadTasks];
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        if (!operation.isCancelled)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [error localizedDescription],@"error",
                                                 nil]];
            });
        }
    };
    
    void (^bodyConstructorBlock)(id <AFMultipartFormData> formData) =^(id <AFMultipartFormData> formData) {
        NSError *error = nil;
        [formData appendPartWithFileURL:[NSURL fileURLWithPath:localPath] name:@"file" error:&error];
        if (error)
        {
            NSLog(@"uploadLocalFile : error %@",[error description]);
        }
    };

    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    uploadOperation = [self.manager POST:[self createUrlWithPath:[NSString stringWithFormat:@"api/v3/upload/%ld/send",(long)uploadTaskID]]
                              parameters:nil
               constructingBodyWithBlock:bodyConstructorBlock
                                 success:successBlock
                                 failure:failureBlock];
    
    __block long long lastNotifiedProgress = 0;
    [uploadOperation setUploadProgressBlock:^(NSUInteger bytesWritten, long long totalBytesWritten, long long totalBytesExpectedToWrite) {
        // Call delegate every 0,5% of progress (to limit the impact on performances)
        if ((totalBytesWritten >= lastNotifiedProgress + totalBytesExpectedToWrite/200) || (totalBytesWritten == totalBytesExpectedToWrite))
        {
            lastNotifiedProgress = totalBytesWritten;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate CMUploadProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     [NSNumber numberWithLongLong:totalBytesWritten],@"uploadedBytes",
                                                     [NSNumber numberWithLongLong:totalBytesExpectedToWrite],@"totalBytes",
                                                     [NSNumber numberWithFloat:(float)((float)totalBytesWritten/(float)totalBytesExpectedToWrite)],@"progress",
                                                     nil]];
            });
        }
    }];
}

// This is used to delete an upload task.
- (void)deleteUploadTask:(NSInteger)taskID
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        [self cleanUploadTasks];
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager DELETE:[self createUrlWithPath:[NSString stringWithFormat:@"api/v3/upload/%ld",(long)taskID]]
              parameters:nil
                 success:successBlock
                 failure:failureBlock];
}

// This is used to remove finished upload tasks.
- (void)cleanUploadTasks
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager DELETE:[self createUrlWithPath:@"api/v3/upload/clean"]
              parameters:nil
                 success:successBlock
                 failure:failureBlock];
}

#pragma mark - url management

#ifndef APP_EXTENSION
// FIXME: remove shared link when not needed anymore
- (NetworkConnection *)urlForFile:(FileItem *)file
{
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.url = nil; // To be filled after
    networkConnection.urlType = URLTYPE_HTTP;
    networkConnection.requestHeaders = [NSMutableDictionary dictionaryWithObject:self.sessionToken forKey:@"X-Fbx-App-Auth"];
    
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            networkConnection.url = [NSURL URLWithString:[[JSON objectForKey:@"result"] objectForKey:@"fullurl"]];
        }
        else
        {
            networkConnection.url = [NSURL URLWithString:@""];
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
        
        NSString *errorMessage;
        if (([operation.responseObject objectForKey:@"success"]) && ([[operation.responseObject objectForKey:@"success"] boolValue] == NO))
        {
            errorMessage = [operation.responseObject objectForKey:@"msg"];
        }
        else
        {
            errorMessage = [error localizedDescription];
        }
        networkConnection.url = [NSURL URLWithString:@""];
    };
    
    // Set sharing duration to 5 hours
    NSDate *expiredate = [NSDate dateWithTimeIntervalSinceNow:(5*60*60)];
    
    NSData *base64Data = [[file.fullPath dataUsingEncoding:NSUTF8StringEncoding] base64EncodedDataWithOptions:0];
    NSString *base64path = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithInteger:(NSInteger)[expiredate timeIntervalSince1970]],@"expire",
                            base64path,@"path",
                            @"",@"fullurl",
                            [NSNumber numberWithBool:YES],@"internal", // This is undocumented, allows to hide share from user
                            nil];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager POST:[self createUrlWithPath:@"api/v3/share_link/"]
            parameters:params
               success:successBlock
               failure:failureBlock];
    
    while (networkConnection.url == nil)
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    }
    
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
                   CMSupportedFeaturesMaskDeleteCancel    |
                   CMSupportedFeaturesMaskFileRename      |
                   CMSupportedFeaturesMaskFolderRename    |
                   CMSupportedFeaturesMaskFolderCreate    |
                   CMSupportedFeaturesMaskFileMove        |
                   CMSupportedFeaturesMaskFolderMove      |
                   CMSupportedFeaturesMaskMoveCancel      |
                   CMSupportedFeaturesMaskFileCopy        |
                   CMSupportedFeaturesMaskFolderCopy      |
                   CMSupportedFeaturesMaskCopyCancel      |
                   CMSupportedFeaturesMaskExtract         |
                   CMSupportedFeaturesMaskExtractCancel   |
                   CMSupportedFeaturesMaskCompress        |
                   CMSupportedFeaturesMaskCompressCancel  |
                   CMSupportedFeaturesMaskFileShare       |
                   CMSupportedFeaturesMaskFolderShare     |
                   CMSupportedFeaturesMaskFileDownload    |
                   CMSupportedFeaturesMaskDownloadCancel  |
                   CMSupportedFeaturesMaskFileUpload      |
                   CMSupportedFeaturesMaskUploadCancel    |
                   CMSupportedFeaturesMaskQTPlayer        |
                   CMSupportedFeaturesMaskVLCPlayer       |
                   CMSupportedFeaturesMaskVideoSeek       |
                   CMSupportedFeaturesMaskAirPlay         |
                   CMSupportedFeaturesMaskGoogleCast;
    }
    else
    {
        features = CMSupportedFeaturesMaskEject;
    }
    return features;
}

- (NSInteger)supportedArchiveType
{
    NSInteger supportedTypes = CMSupportedArchivesMaskZip      |
                               CMSupportedArchivesMaskTar      |
                               CMSupportedArchivesMaskTarGz    |
                               CMSupportedArchivesMaskTarBz2   |
                               CMSupportedArchivesMaskTarXz    |
                               CMSupportedArchivesMaskTarLzma  |
                               CMSupportedArchivesMask7z       |
                               CMSupportedArchivesMaskCpio     |
                               CMSupportedArchivesMaskCpioGz   |
                               CMSupportedArchivesMaskCpioBz2  |
                               CMSupportedArchivesMaskCpioXz   |
                               CMSupportedArchivesMaskCpioLzma |
                               CMSupportedArchivesMaskIso9660;
    return supportedTypes;
}

- (NSInteger)supportedSharingFeatures
{
    NSInteger supportedFeatures = CMSupportedSharingMaskValidityPeriod;
    return supportedFeatures;
}

#pragma mark - Private methods

-  (NSString *)bundleName
{
    // Always return main application bundle name (for app extensions, remove last component)
#ifdef APP_EXTENSION
    NSMutableArray *components = [NSMutableArray arrayWithArray:[[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"] componentsSeparatedByString:@"."]];
    while ([components count] > 3) {
        [components removeLastObject];
    }
    return [components componentsJoinedByString:@"."];
#else
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
#endif
}

- (void)serverData
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            if ([[[JSON objectForKey:@"result"] objectForKey:@"board_name"] isEqualToString:@"fbxgw1r"])
            {
                serverHwModel = @"r1";
            }
            else
            {
                serverHwModel = [[JSON objectForKey:@"result"] objectForKey:@"board_name"];
            }
            serverFirmware = [[JSON objectForKey:@"result"] objectForKey:@"firmware_version"];
            serverSerial = [[JSON objectForKey:@"result"] objectForKey:@"serial"];
            serverMAC = [[JSON objectForKey:@"result"] objectForKey:@"mac"];
        }
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:@"api/v3/system/"]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}

// This is used to delete a task. If the task is still running, it will cancel it
- (void)deleteTask:(NSInteger)taskID
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
    };
    
    void (^failureBlock)(AFHTTPRequestOperation *,NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error) {
        [self HandleRequestFailure:error
                          withJSON:operation.responseObject
                         showAlert:NO];
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager DELETE:[self createUrlWithPath:[NSString stringWithFormat:@"api/v3/fs/tasks/%ld",(long)taskID]]
              parameters:nil
                 success:successBlock
                 failure:failureBlock];
}

// connectionInfo will replace default server access info with public access info
// to enable connection from external networks (public wifi/3G/4G/...)
#ifndef APP_EXTENSION
- (void)connectionInfo
{
    void (^successBlock)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id JSON) {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
        
        if ([[JSON objectForKey:@"success"] boolValue] == YES)
        {
            if ([[[JSON objectForKey:@"result"] objectForKey:@"remote_access"] boolValue])
            {
                self.userAccount.server = [[JSON objectForKey:@"result"] objectForKey:@"remote_access_ip"];
                self.userAccount.port = [[[JSON objectForKey:@"result"] objectForKey:@"remote_access_port"] stringValue];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMAction:[NSDictionary dictionaryWithObjectsAndKeys:
                                             NSLocalizedString(@"Information",nil),@"title",
                                             NSLocalizedString(@"Server's information has been updated to allow external access",nil),@"message",
                                             [NSNumber numberWithInteger:BROWSER_ACTION_DO_NOTHING],@"action",
                                             nil]];
                });
                
                /* Save updated information */
                NSNotification* notification = [NSNotification notificationWithName:@"UPDATEACCOUNT"
                                                                             object:self
                                                                           userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                     self.userAccount,@"account",
                                                                                     nil]];
                
                [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:)
                                                                       withObject:notification waitUntilDone:YES];
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:YES],@"success",
                                    nil]];
        });
    };
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [self.manager GET:[self createUrlWithPath:@"api/v3/connection/config/"]
           parameters:nil
              success:successBlock
              failure:failureBlock];
}
#endif

- (BOOL)isCompressed:(NSString *)type
{
    BOOL supportedArchiveType = NO;
    if ([[type lowercaseString] isEqualToString:@"iso"] ||
        [[type lowercaseString] isEqualToString:@"zip"] ||
        [[type lowercaseString] isEqualToString:@"tar"] ||
        [[type lowercaseString] isEqualToString:@"gz"] ||
        [[type lowercaseString] isEqualToString:@"bz2"] ||
        [[type lowercaseString] isEqualToString:@"7z"] ||
        [[type lowercaseString] isEqualToString:@"rar"] ||
        [[type lowercaseString] isEqualToString:@"xz"] ||
        [[type lowercaseString] isEqualToString:@"lzma"] ||
        [[type lowercaseString] isEqualToString:@"cpio"])
    {
        supportedArchiveType = YES;
    }
    return supportedArchiveType;
}

@end
