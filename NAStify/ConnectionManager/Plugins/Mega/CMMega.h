//
//  CMMega.h
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
#import "MEGASdk.h"

@interface CMMega : NSObject <CM,MEGARequestDelegate,MEGATransferDelegate,UIAlertViewDelegate>

@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

@property(nonatomic, strong) MEGASdk *megaSDK;

// FileList management
@property(nonatomic, strong) FileItem *listPath;

// Delete management
#ifndef APP_EXTENSION
@property(nonatomic, strong) NSArray *deleteFilesArray;
@property(nonatomic) NSInteger deleteFileIndex;
@property(nonatomic) BOOL deleteFileCancel;
#endif

// Move management
#ifndef APP_EXTENSION
@property(nonatomic, strong) NSArray *moveFilesArray;
@property(nonatomic, strong) MEGANode *moveDestFolder;
@property(nonatomic) BOOL moveOverwrite;
@property(nonatomic) NSInteger moveFileIndex;
@property(nonatomic) BOOL moveFileCancel;
#endif

// Copy management
#ifndef APP_EXTENSION
@property(nonatomic, strong) NSArray *cpyFilesArray;
@property(nonatomic, strong) MEGANode *cpyDestFolder;
@property(nonatomic) BOOL cpyOverwrite;
@property(nonatomic) NSInteger cpyFileIndex;
@property(nonatomic) BOOL cpyFileCancel;
#endif

// Share management
#ifndef APP_EXTENSION
@property(nonatomic, strong) NSMutableString *sharedLinks;
@property(nonatomic, strong) NSArray *shareFilesArray;
@property(nonatomic) NSInteger shareFileIndex;
#endif

// Download management
@property(nonatomic, strong) MEGATransfer *downloadTask;

// Upload management
@property(nonatomic, strong) MEGATransfer *uploadTask;

- (NSArray *)serverInfo;
- (BOOL)login;
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

/* Server features */
- (long long)supportedFeaturesAtPath:(NSString *)path;

@end
