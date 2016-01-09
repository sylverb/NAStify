//
//  CMSamba.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <arpa/inet.h>
#include <bdsm/bdsm.h>

@interface CMSamba : NSObject <CM>
{
    // GCD queue
    dispatch_queue_t backgroundQueue;
}

@property(nonatomic) in_addr_t hostIP;
@property(nonatomic) netbios_ns* ns;
@property(nonatomic) smb_session *session;
@property(nonatomic) BOOL cancelDownload;
@property(nonatomic) BOOL cancelUpload;
@property(nonatomic) BOOL cancelMove;
@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;
@property(nonatomic, strong) NSString *tempUser;
@property(nonatomic, strong) NSString *tempPassword;

- (NSArray *)serverInfo;
- (BOOL)login;
- (BOOL)logout;
- (void)listForPath:(FileItem *)folder;
#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
#endif
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localpath;
- (void)cancelDownloadTask;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
- (void)cancelUploadTask;
- (void)setCredential:(NSString *)user password:(NSString *)password;
/* File URL requests */
#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file;
#endif

/* Server features */
- (NSInteger)supportedFeaturesAtPath:(NSString *)path;

@end
