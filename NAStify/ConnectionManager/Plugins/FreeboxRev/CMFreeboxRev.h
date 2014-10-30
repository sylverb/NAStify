//
//  CMFreeboxRev.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"

#import "AFNetworking.h"
#import "AFURLRequestSerialization.h"

@interface CMFreeboxRev : NSObject <CM,UIAlertViewDelegate> {
    // To monitor tasks action progress
    NSInteger deleteTaskID;
    NSInteger copyTaskID;
    NSInteger moveTaskID;
    NSInteger extractTaskID;
    NSInteger compressTaskID;
    NSInteger uploadTaskID;
    
    // Server Info
    NSString *serverHwModel;
    NSString *serverFirmware;
    NSString *serverSerial;
    NSString *serverMAC;
    
    // To cancel ul/dl tasks
    AFHTTPRequestOperation *downloadOperation;
    AFHTTPRequestOperation *uploadOperation;
}

@property(nonatomic, strong) AFHTTPRequestOperationManager *manager;

@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

#ifndef APP_EXTENSION
@property(nonatomic, strong) NSString *extractPassword;
#endif
/* For Association */
@property(nonatomic, strong) NSString *trackID;
@property(nonatomic, strong) NSString *tempToken;
/* For login */
@property(nonatomic, strong) NSString *csrfToken;
@property(nonatomic, strong) NSString *sessionChallenge;
@property(nonatomic, strong) NSString *sessionToken;
/* For multiple file sharing */
#ifndef APP_EXTENSION
@property(nonatomic, strong) NSMutableString *sharedLinks;
@property(nonatomic, strong) NSMutableArray *sharedFiles;
@property(nonatomic, strong) NSString *sharedPassword;
@property(nonatomic) NSTimeInterval sharedInterval;
#endif

- (NSArray *)serverInfo;
- (BOOL)login;
- (BOOL)logout;
- (void)listForPath:(FileItem *)folder;
- (void)spaceInfoAtPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
#ifndef APP_EXTENSION
- (void)ejectFile:(FileItem *)fileItem;
- (void)deleteFiles:(NSArray *)files;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)extractFiles:(NSArray *)files toFolder:(FileItem *)folder withPassword:(NSString *)password overwrite:(BOOL)overwrite extractWithFolder:(BOOL)extractFolders;
- (void)compressFiles:(NSArray *)files toArchive:(NSString *)archive archiveType:(ARCHIVE_TYPE)archiveType compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel password:(NSString *)password overwrite:(BOOL)overwrite;
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password;
- (SHARING_VALIDITY_UNIT)shareValidityUnit;
#endif
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName;
- (void)cancelDownloadTask;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
- (void)cancelUploadTask;
#ifndef APP_EXTENSION
- (void)cancelDeleteTask;
- (void)cancelCopyTask;
- (void)cancelMoveTask;
- (void)cancelExtractTask;
- (void)cancelCompressTask;
#endif

/* File URL requests */
#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file;
#endif

/* Server features */
- (NSInteger)supportedFeaturesAtPath:(NSString *)path;
#ifndef APP_EXTENSION
- (NSInteger)supportedArchiveType;
- (NSInteger)supportedSharingFeatures;
#endif

@end
