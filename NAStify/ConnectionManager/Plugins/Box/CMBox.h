//
//  CMBox.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"
#import <BoxSDK/BoxSDK.h>

@interface CMBox : NSObject <CM,UIAlertViewDelegate> {
#ifndef APP_EXTENSION
    NSInteger deleteRequestsCount;
    NSInteger copyRequestsCount;
    NSInteger moveRequestsCount;
    BOOL moveActionIsRename;
    
    NSURL *streamableURL;
#endif
}

@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

// Server info
@property(nonatomic, strong) NSString *userName;

// Download management
@property(nonatomic, weak) BoxAPIDataOperation *downloadOperation;
@property(nonatomic, weak) BoxAPIMultipartToJSONOperation *uploadOperation;

/* Multiple file sharing */
#ifndef APP_EXTENSION
@property(nonatomic, strong) NSMutableString *sharedLinks;
#endif

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
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password;
#endif
- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder;
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName;
- (void)cancelDownloadTask;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
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
