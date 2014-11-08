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
#import "AFURLRequestSerialization.h"

#define SYNOLOGY_DSM_2_0 2.0f
#define SYNOLOGY_DSM_2_1 2.1f
#define SYNOLOGY_DSM_2_2 2.2f
#define SYNOLOGY_DSM_2_3 2.3f
#define SYNOLOGY_DSM_3_0 3.0f
#define SYNOLOGY_DSM_3_1 3.1f
#define SYNOLOGY_DSM_3_2 3.2f
#define SYNOLOGY_DSM_4_0 4.0f
#define SYNOLOGY_DSM_4_1 4.1f
#define SYNOLOGY_DSM_4_2 4.2f
#define SYNOLOGY_DSM_4_3 4.3f
#define SYNOLOGY_DSM_5_0 5.0f
#define SYNOLOGY_DSM_5_1 5.1f

@interface CMSynology : NSObject <CM,UIAlertViewDelegate> {
    NSInteger protocolVersion;
    float dsmVersion;
    // Server detailed info
    NSString *serverModel;
    NSString *serverFirmwareVersion;
    NSString *serverCPUInfo;
    NSInteger serverRAMSize;
    NSString *serverSerial;

    // QuickConnect
    NSString *quickConnectServer;
    NSString *quickConnectPort;
    NSString *quickConnectServerExternal;
    NSString *quickConnectPortExternal;
    NSInteger quickConnectRequestsLeft;
    
    // To monitor tasks action progress
#ifndef APP_EXTENSION
    id deleteTaskID;
    id copyTaskID;
    id moveTaskID;
    id extractTaskID;
    id compressTaskID;
#endif
    id searchTaskID;
    
    // Token for DSM 4.3
    NSString *synoToken;
    
    // To manage reconnection
    NSDate *lastRequestDate;
    NSTimeInterval timeoutDuration;
    
    // To cancel download & upload tasks
    AFHTTPRequestOperation *downloadOperation;
    AFHTTPRequestOperation *uploadOperation;
    
    /* Multiple files extract handling */
#ifndef APP_EXTENSION
    NSMutableArray *extractFilesList;
    NSString *extractPassword;
    FileItem *extractFolder;
    BOOL extractOverwrite;
    BOOL extractWithFolder;
#endif
}

@property(nonatomic, strong) AFHTTPRequestOperationManager *manager;

@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

- (NSArray *)serverInfo;
- (BOOL)login;
- (void)sendOTP:(NSString *)otp;
- (BOOL)logout;
#ifndef APP_EXTENSION
- (void)sendOTPEmergencyCode;
#endif
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
- (void)cancelDeleteTask;
- (void)cancelCopyTask;
- (void)cancelMoveTask;
- (void)cancelCompressTask;
- (void)cancelExtractTask;
#endif
- (void)cancelSearchTask;

/* File URL requests */
#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file;
- (NetworkConnection *)urlForVideo:(FileItem *)file;
#endif

/* Server features */
- (NSInteger)supportedFeaturesAtPath:(NSString *)path;
#ifndef APP_EXTENSION
- (NSInteger)supportedArchiveType;
- (NSInteger)supportedSharingFeatures;
#endif

@end
