//
//  CMSamba.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "CMSamba.h"
#import "NSStringAdditions.h"
#import "SBNetworkActivityIndicator.h"
#import "SSKeychain.h"

#import <arpa/inet.h>
#import <netdb.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <unistd.h>
#import <dlfcn.h>
#import <notify.h>

char c_user[255];
char c_password[255];

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

- (BOOL)isIPAddress:(NSString *)address
{
    BOOL isIPAddress = NO;
    NSArray *components = [address componentsSeparatedByString:@"."];
    NSCharacterSet *invalidCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"1234567890"] invertedSet];
    
    if ([components count] == 4) {
        NSString *part1 = [components objectAtIndex:0];
        NSString *part2 = [components objectAtIndex:1];
        NSString *part3 = [components objectAtIndex:2];
        NSString *part4 = [components objectAtIndex:3];
        
        if ([part1 rangeOfCharacterFromSet:invalidCharacters].location == NSNotFound &&
            [part2 rangeOfCharacterFromSet:invalidCharacters].location == NSNotFound &&
            [part3 rangeOfCharacterFromSet:invalidCharacters].location == NSNotFound &&
            [part4 rangeOfCharacterFromSet:invalidCharacters].location == NSNotFound ) {
            
            if ([part1 intValue] < 255 &&
                [part2 intValue] < 255 &&
                [part3 intValue] < 255 &&
                [part4 intValue] < 255) {
                isIPAddress = YES;
            }
        }
    }
    
    return isIPAddress;
}

#pragma mark - Server Info

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
                           [NSString stringWithFormat:NSLocalizedString(@"Workgroup: %s",nil), self.userAccount.serverObject],
                           [NSString stringWithFormat:NSLocalizedString(@"User: %@",nil), user],
                           nil];
    return serverInfo;
}

#pragma mark - login/logout management

- (BOOL)login
{
    struct in_addr addr;
    
    self.ns = netbios_ns_new();
    
    if ([self isIPAddress:self.userAccount.server])
    {
        inet_aton([self.userAccount.server cStringUsingEncoding:NSUTF8StringEncoding], &addr);
    }
    else
    {
        if (!netbios_ns_resolve(self.ns,
                                [self.userAccount.server cStringUsingEncoding:NSUTF8StringEncoding],
                                NETBIOS_FILESERVER,
                                &addr.s_addr))
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMLogin:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO],@"success",
                                        NSLocalizedString(@"Unable to find server", nil),@"error",
                                        nil]];
            });
            return YES;
        }
    }
    self.hostIP = addr.s_addr;
    
    self.session = smb_session_new();
    if (!self.session)
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
        if (self.tempPassword.length !=0)
        {
            strcpy(c_password, [self.tempPassword cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        else
        {
            strcpy(c_password, "\0");
        }
    }
    else if ((self.userAccount.userName) && ([self.userAccount.userName length] != 0))
    {
        NSString *password = [SSKeychain passwordForService:self.userAccount.uuid account:@"password"];
        strcpy(c_user,[self.userAccount.userName cStringUsingEncoding:NSUTF8StringEncoding]);
        if (password.length !=0)
        {
            strcpy(c_password, [password cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        else
        {
            strcpy(c_password, "\0");
        }
    }
    else
    {
        strcpy(c_user, "guest");
        strcpy(c_password, "\0");
    }
    
    if (smb_session_connect(self.session, [self.userAccount.server cStringUsingEncoding:NSUTF8StringEncoding],
                            self.hostIP, SMB_TRANSPORT_TCP))
    {
        if (smb_session_is_guest(self.session))
            NSLog(@"Login FAILED but we were logged in as GUEST \n");
        else
            NSLog(@"Connect ok");
    }
    else
    {
        NSLog(@"Error");
    }

    smb_session_set_creds(self.session, [self.userAccount.server cStringUsingEncoding:NSUTF8StringEncoding], c_user, c_password);
    if (!smb_session_login(self.session))
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMCredentialRequest:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSString stringWithFormat:@"smb://%@",self.userAccount.server],@"service",
                                                nil]];
        });
        return YES;
    }

    // Return YES if we need to wait for the login answer to continue
    // This is needed if the login process if needed to build other requests
    // to include cookies or sessionId for example or to check if we can connect
    return NO;
}

- (BOOL)logout
{
    if (self.session)
    {
        smb_session_destroy(self.session);
        netbios_ns_destroy(self.ns);
    }
    return NO;
}

#pragma mark - list files management

- (void)listForPath:(FileItem *)folder
{
    smb_stat            st;
    char                **share_list;
    smb_file            *files;
    
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    if ([[folder.objectIds lastObject] isEqual:kRootID])
    {
        // Get shares list
        if (!smb_share_get_list(self.session, &share_list))
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            folder.path,@"path",
                                            NSLocalizedString(@"Unable to list shares", nil),@"error",
                                            nil]];
            });
            return;
        }
        
        NSLog(@"Share list :");
        NSMutableArray *filesOutputArray = [NSMutableArray array];
        for (size_t j = 0; share_list[j] != NULL; j++)
        {
            NSLog(@"- %s\n", share_list[j]);

            if ((strcmp(share_list[j], "IPC$\0") != 0) &&
                (strcmp(share_list[j], "lp\0")))
            {
                NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithBool:YES],@"isdir",
                                          [NSString stringWithCString:share_list[j] encoding:NSUTF8StringEncoding],@"filename",
                                          [NSString stringWithCString:share_list[j] encoding:NSUTF8StringEncoding],@"id",
                                          [NSNumber numberWithBool:NO],@"iscompressed",
                                          [NSNumber numberWithBool:NO],@"writeaccess",
                                          @"",@"type",
                                          nil];
                [filesOutputArray addObject:dictItem];
            }
        }
        smb_share_list_destroy(share_list);
        
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
        smb_tid tid = smb_tree_connect(self.session, [[folder.objectIds objectAtIndex:1] cStringUsingEncoding:NSUTF8StringEncoding]);
        if (tid == 0)
        {
            // Username/password is invalid for this share, request another one
            [self.delegate CMCredentialRequest:[NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSString stringWithFormat:@"smb://%@",self.userAccount.server],@"service",
                                                nil]];
            return;
        }
        
        NSMutableString *path = [[NSMutableString alloc] init];
        for (NSInteger i = 2;i < folder.objectIds.count; i++)
        {
            [path appendFormat:@"\\%@",[folder.objectIds objectAtIndex:i]];
        }
        [path appendString:@"\\*"];
        
        files = smb_find(self.session, tid, [path cStringUsingEncoding:NSUTF8StringEncoding]);
        
        size_t files_count = smb_stat_list_count( files );
        if (files_count <= 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithBool:NO],@"success",
                                            folder.path,@"path",
                                            NSLocalizedString(@"Unable to list files", nil),@"error",
                                            nil]];
            });
            return;
        }
        else
        {
            NSMutableArray *filesOutputArray = [NSMutableArray array];

            for( size_t i = 0; i < files_count; i++ )
            {
                st = smb_stat_list_at( files, i );
                if( st == NULL )
                {
                    NSLog(@"smb_stat_list_at failed\n");
                    continue;
                }
                fprintf(stdout, "Found a file %s \n", smb_stat_name( st ));
                
                NSString *name = [NSString stringWithCString:smb_stat_name(st) encoding:NSUTF8StringEncoding];
                if (([name isEqualToString:@"."]) ||
                    ([name isEqualToString:@".."]))
                {
                    continue;
                }
                NSString *type = @"";
                if ([[name componentsSeparatedByString:@"."] count] > 1)
                {
                    type = [[name componentsSeparatedByString:@"."] lastObject];
                }

                NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithBool:smb_stat_get(st,SMB_STAT_ISDIR)],@"isdir",
                                          name,@"filename",
                                          [NSNumber numberWithLongLong:smb_stat_get(st,SMB_STAT_SIZE)],@"filesizenumber",
                                          name,@"id",
                                          [NSNumber numberWithBool:NO],@"iscompressed",
                                          [NSNumber numberWithBool:YES],@"writeaccess",
                                          [NSNumber numberWithDouble:smb_stat_get(st,SMB_STAT_MTIME)],@"date",
                                          type,@"type",
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
        smb_tree_disconnect(self.session, tid);
        smb_stat_list_destroy(files);
    }
    
#ifndef APP_EXTENSION
    [[UIApplication sharedApplication] endBackgroundTask:bgTask];
    bgTask = UIBackgroundTaskInvalid;
#endif
}

#pragma mark - space info management

#pragma mark - Download management

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
#define BUFFER_SIZE 4096
    char buffer[BUFFER_SIZE];
    ssize_t read_length = 0;
    ssize_t length;
    BOOL success = YES;
    smb_fd fd;
    smb_tid tid;

#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    tid = smb_tree_connect(self.session, [[file.objectIds objectAtIndex:1] cStringUsingEncoding:NSUTF8StringEncoding]);
    if (tid == 0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               NSLocalizedString(@"Unable to connect to share", nil),@"error",
                                               nil]];
        });
        return;
    }
    
    NSMutableString *path = [[NSMutableString alloc] init];
    for (NSInteger i = 2;i < file.objectIds.count; i++)
    {
        [path appendFormat:@"\\%@",[file.objectIds objectAtIndex:i]];
    }

    NSLog(@"path %s",[path cStringUsingEncoding:NSUTF8StringEncoding]);
    fd = smb_fopen(self.session, tid, [path cStringUsingEncoding:NSUTF8StringEncoding], SMB_MOD_RO);
    if (!fd)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               NSLocalizedString(@"Unable to access requested file", nil),@"error",
                                               nil]];
        });
        smb_tree_disconnect(self.session, tid);

        return;
    }
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    [fm createFileAtPath:localName
                contents:nil
              attributes:nil];
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingToURL:[NSURL fileURLWithPath:localName] error:NULL];
    
    while (read_length < [file.fileSizeNumber longLongValue])
    {
        length = smb_fread(self.session, fd, buffer, BUFFER_SIZE);
        if (length != -1)
        {
            read_length += length;
            [fileHandle writeData:[NSData dataWithBytes:buffer length:BUFFER_SIZE]];
        }
        else
        {
            success = NO;
            break;
        }
    }
    
    [fileHandle closeFile];
    smb_fclose(self.session, fd);
    smb_tree_disconnect(self.session, tid);

    if (success)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
        });
    }
    else
    {
        // Delete partially donwloaded file
        [fm removeItemAtPath:localName error:NULL];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               NSLocalizedString(@"Unable to access requested file", nil),@"error",
                                               nil]];
        });
    }
    
#ifndef APP_EXTENSION
    [[UIApplication sharedApplication] endBackgroundTask:bgTask];
    bgTask = UIBackgroundTaskInvalid;
#endif
}

#pragma mark - Credentials management

- (void)setCredential:(NSString *)user password:(NSString *)password
{
    self.tempUser = user;
    self.tempPassword = password;
}

- (NetworkConnection *)urlForFile:(FileItem *)file
{
    NSMutableString *uri = [[NSMutableString alloc] initWithFormat:@"smb://%@",[self.userAccount.server encodeStringUrl:NSUTF8StringEncoding]];
    for (NSInteger i = 1;i < file.objectIds.count; i++)
    {
        [uri appendFormat:@"/%@",[[file.objectIds objectAtIndex:i] encodeStringUrl:NSUTF8StringEncoding]];
    }

    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.url = [NSURL URLWithString:uri];
    networkConnection.urlType = URLTYPE_SMB;
    networkConnection.workgroup = self.userAccount.serverObject;
    networkConnection.user = [NSString stringWithCString:c_user encoding:NSUTF8StringEncoding];
    networkConnection.password = [NSString stringWithCString:c_password encoding:NSUTF8StringEncoding];
    return networkConnection;
}

#pragma mark - supported features

- (NSInteger)supportedFeaturesAtPath:(NSString *)path
{
    NSInteger features = (
                          CMSupportedFeaturesMaskVLCPlayer
                          );
    return features;
}

@end
