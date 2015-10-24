//
//  CMFtp.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"
#import "curl.h"

struct CurlMemoryStruct {
    char *memory;
    size_t size;
};

@interface CMFtp : NSObject <CM> {
    // GCD queue
    dispatch_queue_t backgroundQueue;

    CURL *curl;
}

@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;
#ifndef APP_EXTENSION
@property(nonatomic) BOOL cancelDelete;
@property(nonatomic) NSInteger filesToDeleteCount;
@property(nonatomic, strong) NSMutableArray *filesToDelete;
@property(nonatomic) BOOL cancelMove;
@property(nonatomic) NSInteger filesToMoveCount;
@property(nonatomic, strong) NSMutableArray *filesToMove;
#endif

- (NSArray *)serverInfo;
- (BOOL)login;
- (void)listForPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files;
- (void)cancelDeleteTask;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)cancelMoveTask;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
#endif
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName;
- (void)cancelDownloadTask;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
- (void)cancelUploadTask;

/* File URL requests */
#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file;
- (NetworkConnection *)urlForVideo:(FileItem *)file;
#endif

/* Server features */
- (long long)supportedFeaturesAtPath:(NSString *)path;

@end
