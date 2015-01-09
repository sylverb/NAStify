//
//  CMOneDrive.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"

#import "AFNetworking.h"
#import "SBNetworkActivityIndicator.h"
#import "LiveConnectClient.h"

@interface CMOneDrive : NSObject <LiveAuthDelegate,LiveOperationDelegate,LiveDownloadOperationDelegate,LiveUploadOperationDelegate,CM,UIAlertViewDelegate>

@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

@property(nonatomic, strong) LiveConnectClient *liveClient;

// FileList management
@property(nonatomic, strong) NSString *path;
@property(nonatomic, strong) LiveOperation *fileListOperation;

// Space info management
@property(nonatomic, strong) LiveOperation *spaceInfoOperation;

// Folder creation management
@property(nonatomic, strong) LiveOperation *createFolderOperation;

// Rename management
@property(nonatomic, strong) LiveOperation *renameOperation;

// Delete management
#ifndef APP_EXTENSION
@property(nonatomic, strong) LiveOperation *deleteOperation;
@property(nonatomic, strong) NSArray *deleteFilesArray;
@property(nonatomic) NSInteger deleteFileIndex;
#endif

// Move management
#ifndef APP_EXTENSION
@property(nonatomic, strong) LiveOperation *moveOperation;
@property(nonatomic, strong) NSArray *moveFilesArray;
@property(nonatomic, strong) NSString *moveDestFolder;
@property(nonatomic) BOOL moveOverwrite;
@property(nonatomic) NSInteger moveFileIndex;
#endif

// Copy management
#ifndef APP_EXTENSION
@property(nonatomic, strong) LiveOperation *cpyOperation;
@property(nonatomic, strong) NSArray *cpyFilesArray;
@property(nonatomic, strong) NSString *cpyDestFolder;
@property(nonatomic) BOOL cpyOverwrite;
@property(nonatomic) NSInteger cpyFileIndex;
#endif

// Share management
#ifndef APP_EXTENSION
@property(nonatomic, strong) LiveOperation *shareOperation;
@property(nonatomic, strong) NSMutableString *sharedLinks;
@property(nonatomic, strong) NSArray *shareFilesArray;
@property(nonatomic) NSInteger shareFileIndex;
#endif

// Download management
@property(nonatomic, strong) NSString *destPath;
@property(nonatomic, strong) LiveDownloadOperation *downloadOperation;

// Upload management
@property(nonatomic, strong) LiveOperation *uploadOperation;

- (BOOL)login;
- (NSArray *)serverInfo;
- (void)listForPath:(FileItem *)folder;
- (void)spaceInfoAtPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)cancelMoveTask;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)cancelCopyTask;
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password;
#endif
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localpath;
- (void)cancelDownloadTask;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
- (void)cancelUploadTask;

/* File URL requests */
- (NetworkConnection *)urlForFile:(FileItem *)file;

/* Server features */
- (long long)supportedFeaturesAtPath:(NSString *)path;

@end
