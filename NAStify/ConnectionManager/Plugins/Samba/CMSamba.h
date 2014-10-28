//
//  CMWebDav.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#if 0

#import "libsmbclient.h"
#import "talloc_stack.h"

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
    
} KxSMBError;

@interface CMSamba : NSObject <CM,UIAlertViewDelegate>
{
    // GCD queue
    dispatch_queue_t backgroundQueue;
    SMBCCTX *smbContext;
}

@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

- (BOOL)login;
- (BOOL)logout;
- (void)listForPath:(FileItem *)folder;
- (void)deleteFiles:(NSArray *)files;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localpath;

- (NetworkConnection *)urlForFile:(FileItem *)file;

/* Server features */
- (NSInteger)supportedFeaturesAtPath:(NSString *)path;

@end

#endif