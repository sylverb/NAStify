//
//  CMGoogleDrive.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"
#import "GTLDrive.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLUtilities.h"
#import "GTMHTTPFetcherLogging.h"

@interface CMGoogleDrive : NSObject <CM,UIAlertViewDelegate>

@property(nonatomic, strong) GTMOAuth2Authentication *authentication;
@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, strong) GTLServiceDrive *serviceDrive;
@property(nonatomic, weak)   id <CMDelegate> delegate;

// Server Info management
@property(nonatomic, strong) NSString *usedQuota;

// Download management
@property(nonatomic, strong) GTMHTTPFetcher *fetcher;

// Upload management
@property(nonatomic, strong) GTLServiceTicket *uploadTicket;

// Move management
#ifndef APP_EXTENSION
@property(nonatomic, strong) GTLServiceTicket *moveTicket;
@property(nonatomic, strong) NSArray *moveFilesArray;
@property(nonatomic, strong) FileItem *moveDestFolder;
@property(nonatomic) NSInteger moveFileIndex;
@property(nonatomic) BOOL moveOverwrite;
#endif

// Delete management
#ifndef APP_EXTENSION
@property(nonatomic, strong) GTLServiceTicket *deleteTicket;
@property(nonatomic, strong) NSArray *deleteFilesArray;
@property(nonatomic) NSInteger deleteFileIndex;
#endif

// Copy management
#ifndef APP_EXTENSION
@property(nonatomic, strong) GTLServiceTicket *cpyTicket;
@property(nonatomic, strong) NSArray *cpyFilesArray;
@property(nonatomic, strong) FileItem *cpyDestFolder;
@property(nonatomic) NSInteger cpyFileIndex;
@property(nonatomic) BOOL cpyOverwrite;
#endif

// Search management
@property(nonatomic, strong) GTLServiceTicket *searchTicket;

// Multiple file sharing
#ifndef APP_EXTENSION
@property(nonatomic, strong) NSArray *shareFilesArray;
@property(nonatomic) NSInteger shareFileIndex;
@property(nonatomic, strong) NSMutableString *sharedLinks;
#endif

- (NSArray *)serverInfo;
- (BOOL)login;
- (void)listForPath:(FileItem *)folder;
- (void)spaceInfoAtPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files;
- (void)cancelDeleteTask;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)cancelMoveTask;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)cancelCopyTask;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder;
- (void)cancelSearchTask;
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password;
#endif
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
- (void)cancelDownloadTask;
- (void)cancelUploadTask;

/* File URL requests */
#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file;
#endif

/* Server features */
- (long long)supportedFeaturesAtPath:(NSString *)path;
#ifndef APP_EXTENSION
- (NSInteger)supportedSharingFeatures;
#endif

@end
