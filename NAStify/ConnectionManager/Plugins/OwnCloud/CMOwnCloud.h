//
//  CMOwnCloud.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"

#import "OCCommunication.h"
#import "SBNetworkActivityIndicator.h"
#import "AFNetworking.h"

@interface CMOwnCloud : NSObject <CM,UIAlertViewDelegate>

@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

@property(nonatomic, strong) OCCommunication* ocCommunication;
@property(nonatomic, strong) NSOperation *downloadOperation;
@property(nonatomic, strong) NSOperation *uploadOperation;

/* File deleting management */
#ifndef APP_EXTENSION
@property(nonatomic, strong) NSArray *deleteFilesArray;
@property(nonatomic) NSUInteger deletingFileIndex;
@property(nonatomic) BOOL deleteCancel;
#endif

/* File moving management */
#ifndef APP_EXTENSION
@property(nonatomic, strong) NSArray *moveFilesArray;
@property(nonatomic) NSUInteger movingFileIndex;
@property(nonatomic, strong) NSString *moveDestPath;
@property(nonatomic) BOOL moveOverwrite;
@property(nonatomic) BOOL moveCancel;
#endif

/* File sharing management */
#ifndef APP_EXTENSION
@property(nonatomic, strong) NSMutableString *sharedLinks;
@property(nonatomic, strong) NSArray *sharedFilesArray;
@property(nonatomic) NSUInteger sharingFileIndex;
#endif

- (NSArray *)serverInfo;
- (void)listForPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password;
#endif
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localpath;
- (void)cancelDownloadTask;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
- (void)cancelUploadTask;

/* File URL requests */
#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file;
#endif

/* Server features */
- (NSInteger)supportedFeaturesAtPath:(NSString *)path;

@end
