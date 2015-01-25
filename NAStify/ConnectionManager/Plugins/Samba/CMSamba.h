//
//  CMSamba.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#ifdef SAMBA
#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#import <libsmbclient.h>
#import <talloc_stack.h>

typedef enum {
    
    KxSMBErrorUnknown,
    KxSMBErrorInvalidArg,
    KxSMBErrorInvalidProtocol,
    KxSMBErrorOutOfMemory,
    KxSMBErrorPermissionDenied,
    KxSMBErrorInvalidPath,
    KxSMBErrorPathIsNotDir,
    KxSMBErrorPathIsDir,
    KxSMBErrorWorkgroupNotFound,
    KxSMBErrorShareDoesNotExist,
    KxSMBErrorItemAlreadyExists,
    KxSMBErrorDirNotEmpty,
    KxSMBErrorFileIO,
    KxSMBErrorBusy,
    KxSMBErrorRefused,
} KxSMBError;

#ifndef APP_EXTENSION
static NSError *mkKxSMBError(KxSMBError error, NSString *format, ...);
#endif

@interface CMSamba : NSObject <CM,UIAlertViewDelegate>
{
    // GCD queue
    dispatch_queue_t backgroundQueue;
}

@property(nonatomic) SMBCCTX *smbContext;
@property(nonatomic) BOOL cancelDownload;
@property(nonatomic) BOOL cancelUpload;
@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;
@property(nonatomic, strong) NSString *tempUser;
@property(nonatomic, strong) NSString *tempPassword;


- (NSArray *)serverInfo;
- (BOOL)login;
- (BOOL)logout;
- (void)listForPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
#endif
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localpath;
- (void)cancelDownloadTask;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
- (void)cancelUploadTask;
- (void)setCredential:(NSString *)user password:(NSString *)password;

/* Server features */
- (NSInteger)supportedFeaturesAtPath:(NSString *)path;

@end
#endif