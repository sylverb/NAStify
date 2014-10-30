//
//  CMLocal.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"
#import "HTTPServer.h"

@interface CMLocal : NSObject <CM,UIAlertViewDelegate>

@property(nonatomic, strong) HTTPServer *httpServer;
@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

@property(nonatomic, strong) NSFileManager *fileManager;

- (NSArray *)serverInfo;
- (void)listForPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
#ifndef APP_EXTENSION
- (void)spaceInfoAtPath:(FileItem *)folder;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)deleteFiles:(NSArray *)files;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder;
- (void)compressFiles:(NSArray *)files toArchive:(NSString *)archive archiveType:(ARCHIVE_TYPE)archiveType compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel password:(NSString *)password overwrite:(BOOL)overwrite;
- (void)extractFiles:(NSArray *)files toFolder:(FileItem *)folder withPassword:(NSString *)password overwrite:(BOOL)overwrite extractWithFolder:(BOOL)extractFolders;
#endif
#ifdef APP_EXTENSION
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName;
#endif
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;

#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file;
#endif

/* Server features */
- (NSInteger)supportedFeaturesAtPath:(NSString *)path;
#ifndef APP_EXTENSION
- (NSInteger)supportedArchiveType;
#endif

@end
