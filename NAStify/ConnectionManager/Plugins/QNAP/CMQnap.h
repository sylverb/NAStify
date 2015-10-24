//
//  CMSynology.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"

#import "AFNetworking.h"

@interface CMQnap : NSObject <CM> {
    NSString *sID; // Session id
    
    // To monitor tasks action progress
#ifndef APP_EXTENSION
    id copyTaskID;
    id moveTaskID;
    id extractTaskID;
    id compressTaskID;
#endif
    
    // Server Info
    NSString *serverModel;
    NSString *serverFirmware;
    NSString *serverHostname;
    
    // To cancel download & upload tasks
    AFHTTPRequestOperation *downloadOperation;
    AFHTTPRequestOperation *uploadOperation;
}

@property(nonatomic, strong) NSString *version;
@property(nonatomic, strong) AFHTTPRequestOperationManager *manager;

@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

- (NSArray *)serverInfo;
- (BOOL)login;
- (BOOL)logout;
- (void)listForPath:(FileItem *)folder;
- (void)spaceInfoAtPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)extractFiles:(NSArray *)files toFolder:(FileItem *)folder withPassword:(NSString *)password overwrite:(BOOL)overwrite extractWithFolder:(BOOL)extractFolders;
- (void)compressFiles:(NSArray *)files toArchive:(NSString *)archive archiveType:(ARCHIVE_TYPE)archiveType compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel password:(NSString *)password overwrite:(BOOL)overwrite;
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password;
- (SHARING_VALIDITY_UNIT)shareValidityUnit;
#endif
- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder;
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName;
- (void)cancelDownloadTask;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
- (void)cancelUploadTask;
#ifndef APP_EXTENSION
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
- (long long)supportedFeaturesAtPath:(NSString *)path;
#ifndef APP_EXTENSION
- (NSInteger)supportedArchiveType;
#endif

@end
