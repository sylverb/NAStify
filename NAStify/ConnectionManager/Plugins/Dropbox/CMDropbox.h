//
//  CMDropbox.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"
#import <DropboxSDK/DropboxSDK.h>

@interface CMDropbox : NSObject <CM,UIAlertViewDelegate,DBNetworkRequestDelegate,DBRestClientDelegate> {
    NSInteger deleteRequestsCount;
    NSInteger copyRequestsCount;
    NSInteger moveRequestsCount;
    BOOL moveActionIsRename;
    
    NSURL *streamableURL;
}

@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

@property(nonatomic, strong) DBRestClient *restClient;

// Download management
@property(nonatomic, strong) NSString *downloadedFile;
@property(nonatomic) long long downloadedFileSize;

// Upload management
@property(nonatomic, strong) DBRestClient *uploadRestClient;
@property(nonatomic, strong) FileItem *uploadedFile;
@property(nonatomic, strong) NSString *uploadedDestFolder;
@property(nonatomic, strong) NSString *existingFileRevision;
@property(nonatomic) BOOL uploadOverwrite;

/* Multiple file sharing */
@property(nonatomic, strong) NSMutableString *sharedLinks;
@property(nonatomic, strong) NSMutableArray *sharedFiles;

- (NSArray *)serverInfo;
- (BOOL)login;
- (BOOL)logout;
- (void)listForPath:(FileItem *)folder;
- (void)spaceInfoAtPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
- (void)deleteFiles:(NSArray *)files;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder;
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password;
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
- (void)cancelDownloadTask;
- (void)cancelUploadTask;

/* File URL requests */
- (NetworkConnection *)urlForFile:(FileItem *)file;

/* Server features */
- (NSInteger)supportedFeaturesAtPath:(NSString *)path;
- (NSInteger)supportedSharingFeatures;
@end
