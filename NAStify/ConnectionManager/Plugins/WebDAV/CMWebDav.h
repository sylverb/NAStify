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

#include "ne_socket.h"
#include "ne_session.h"
#include "ne_request.h"
#include "ne_auth.h"
#include "ne_basic.h"
#include "ne_compress.h"
#include "ne_props.h"
#include "ne_utils.h"
#include "ne_dates.h"
#include "ne_locks.h"

@interface CMWebDav : NSObject <CM>
{
    // GCD queue
    dispatch_queue_t backgroundQueue;
    
    // WebDAV server information
    BOOL trustedCert; // Server's certificate is trusted
}

@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

// Neon session for WebDAV connection
@property(atomic) ne_session* webDavSession;

- (NSArray *)serverInfo;
- (BOOL)login;
- (BOOL)logout;
- (void)listForPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
#endif
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localpath;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;

#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file;
#endif

/* Server features */
- (long long)supportedFeaturesAtPath:(NSString *)path;

@end
