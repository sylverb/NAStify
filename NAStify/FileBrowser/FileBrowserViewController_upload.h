//
//  FileBrowserViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ConnectionManager.h"
#import "FileBrowserCell.h"
#import "ODRefreshControl.h"
#import "MoveFileViewController.h"
#import "SortItemsViewController.h"

#import "ReaderViewController.h"
#import "RBFilePreviewer.h"
#import "MWPhotoBrowser.h"

#import "MBProgressHUD.h"

#import "NSMutableArrayAdditions.h"

#define TAG_ALERT_CREATE_FOLDER 0
#define TAG_ALERT_DO_NOTHING 1
#define TAG_ALERT_DELETE_BASE 0x1000

@interface FileBrowserViewController : UIViewController <CMObserver, UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate, UITextFieldDelegate, MoveFileViewDelegate, UIDocumentInteractionControllerDelegate,ReaderViewControllerDelegate,MWPhotoBrowserDelegate,MBProgressHUDDelegate,SortItemsViewController>

@property(nonatomic, strong) id <CM> connectionManager;

@property(nonatomic, strong) UserAccount *userAccount;

@property(nonatomic, strong) NSString *serverPath;

@property(nonatomic, strong) NSMutableArray *filesArray;

/* sorting handling */
@property(nonatomic) FileItemSortType sortingType;

/* Renaming handling */
@property(nonatomic, strong) FileBrowserCell *editedCell;

/* Multiple Selection handling */
@property(nonatomic, strong) UITableView *multipleSelectionTableView;
@property(nonatomic, strong) NSMutableIndexSet *selectedIndexes;

/* UIBarButtonItems for multiple selection */
@property(nonatomic, strong) UIBarButtonItem *deleteFilesButtonItem;
@property(nonatomic, strong) UIBarButtonItem *moveCopyFilesButtonItem;
@property(nonatomic, strong) UIBarButtonItem *compressFilesButtonItem;
@property(nonatomic, strong) UIBarButtonItem *invertSelectionButtonItem;

/* Action button sheet handling */
@property(nonatomic, strong) UIActionSheet *actionSheet;
@property(nonatomic) NSInteger reloadActionButtonIndex;
@property(nonatomic) NSInteger createFolderActionButtonIndex;
@property(nonatomic) NSInteger sortItemsActionButtonIndex;

/* Long press sheet handling */
@property(nonatomic, strong) UIActionSheet *itemActionSheet;
@property(nonatomic) NSInteger renameButtonIndex;
@property(nonatomic) NSInteger moveCopyButtonIndex;
@property(nonatomic) NSInteger extractButtonIndex;
@property(nonatomic) NSInteger compressButtonIndex;
@property(nonatomic) NSInteger downloadButtonIndex;
@property(nonatomic) NSInteger openInButtonIndex;

/* Add folder alert view */
@property(nonatomic, strong) UITextField *folderNameField;

/* Progress views */
@property(nonatomic, strong) MBProgressHUD *progressHUD;


@property(nonatomic, strong) UIDocumentInteractionController* documentInteractionController;

@property(nonatomic, strong) NSMutableArray *photos;

@property(nonatomic, strong) ODRefreshControl *refreshControl;

/* CMObserver protocol */
- (void)CMLogin:(NSNotification*)notification;
- (void)CMFilesList:(NSNotification*)notification;
- (void)CMSpaceInfo:(NSNotification*)notification;
- (void)CMRename:(NSNotification*)notification;
- (void)CMDeleteFinished:(NSNotification*)notification;
- (void)CMCreateFolder:(NSNotification*)notification;
- (void)CMCopyFinished:(NSNotification*)notification;
- (void)CMMoveFinished:(NSNotification*)notification;
- (void)CMDownloadFinished:(NSNotification *)notification;
- (void)CMUploadProgress:(NSNotification*)notification;
- (void)CMUploadFinished:(NSNotification*)notification;
- (void)CMConnectionError:(NSNotification*)notification;

/* SortingItemsController delegate */
- (void)selectedSortingType:(FileItemSortType)sortingType;

/* CompressViewController delegate */
- (void)compressFiles:(NSArray *)files toArchive:(NSString *)archive archiveType:(ARCHIVE_TYPE)archiveType compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel password:(NSString *)password overwrite:(BOOL)overwrite; // files : array of type FileItem

/* ExtractViewController delegate */
- (void)extractFile:(FileItem *)fileItem toSubdir:(NSString *)toSubdir withPassword:(NSString *)password overwrite:(BOOL)overwrite extractWithFolder:(BOOL)extractFolders;

/* MoveFileViewController delegate */
- (void)moveFiles:(NSArray *)files toPath:(NSString *)toPath andOverwrite:(BOOL)overwrite;
- (void)copyFiles:(NSArray *)files toPath:(NSString *)toPath andOverwrite:(BOOL)overwrite;

/* common to several delegates */
- (void)createFolder:(NSString *)folder atPath:(NSString *)path;

@end
