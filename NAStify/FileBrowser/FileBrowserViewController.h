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
#import "FileBrowserSearchCell.h"
#import "MoveFileViewController.h"
#import "SortItemsViewController.h"
#import "UploadBrowserViewController.h"
#import "ShareViewController.h"
#import "CameraRollSyncViewController.h"

#import "ReaderViewController.h"
#import "RBFilePreviewer.h"
#import "MWPhotoBrowser.h"

#import "MBProgressHUD.h"

#import "CustomSearchDisplayController.h"
#import "UIPopoverController+iPhone.h"

// GoogleCast support
#import "GoogleCastController.h"

// Ads
#import <iAd/iAd.h>
#import "GADInterstitial.h"

@interface FileBrowserViewController : UIViewController <CMDelegate, UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate, UITextFieldDelegate, MoveFileViewDelegate, UploadBrowserViewControllerDelegate, ShareViewDelegate, CameraRollSyncViewDelegate, UIDocumentInteractionControllerDelegate, ReaderViewControllerDelegate, MWPhotoBrowserDelegate, MBProgressHUDDelegate, SortItemsViewController, UISearchBarDelegate, UISearchDisplayDelegate, UINavigationBarDelegate, GCControllerDelegate, GADInterstitialDelegate>
{
    CustomSearchDisplayController	*searchDisplayController;
    
    // Google Cast button handling
    UIImage *_btnImage;
    UIImage *_btnImageSelected;
    
    GoogleCastController *_gcController;
}

@property(nonatomic, strong) id <CM> connectionManager;

@property(nonatomic, strong) UserAccount *userAccount;

@property(nonatomic, strong) FileItem *currentFolder;

@property(nonatomic, strong) NSMutableArray *filesArray;
@property(nonatomic, strong) NSMutableArray *filteredFilesArray;

/* Filtering/Searching handling */
@property(nonatomic, strong) CustomSearchDisplayController *searchDisplayController;
@property(nonatomic, strong) UISearchBar *searchBar;
@property(nonatomic, strong) UILabel *searchBarPlaceholderText;

/* Logout handling */
@property(nonatomic) BOOL isConnected;

/* sorting handling */
@property(nonatomic) FileItemSortType sortingType;

/* Renaming handling */
@property(nonatomic, strong) FileBrowserCell *editedCell;

/* Multiple Selection handling */
@property(nonatomic, strong) UITableView *multipleSelectionTableView;
@property(nonatomic, strong) NSMutableIndexSet *selectedIndexes;

/* Subtitle downloading handling */
@property(nonatomic, strong) NetworkConnection *videoNetworkConnection;
@property(nonatomic, strong) NSString *videoUrl;
@property(nonatomic, strong) NSString *subtitlePath;


/* UIBarButtonItems for multiple selection */
@property(nonatomic, strong) UIBarButtonItem *deleteFilesButtonItem;
@property(nonatomic, strong) UIBarButtonItem *moveCopyFilesButtonItem;
@property(nonatomic, strong) UIBarButtonItem *compressFilesButtonItem;
@property(nonatomic, strong) UIBarButtonItem *invertSelectionButtonItem;
@property(nonatomic, strong) UIBarButtonItem *extractFilesButtonItem;
@property(nonatomic, strong) UIBarButtonItem *shareFilesButtonItem;

/* Action button sheet handling */
@property(nonatomic, strong) UIPopoverController *sortPopoverController;
@property(nonatomic, strong) UIActionSheet *actionSheet;
@property(nonatomic) NSInteger reloadActionButtonIndex;
@property(nonatomic) NSInteger createFolderActionButtonIndex;
@property(nonatomic) NSInteger uploadButtonIndex;
@property(nonatomic) NSInteger serverInfoButtonIndex;
@property(nonatomic) NSInteger cameraRollSyncButtonIndex;

/* Long press sheet handling */
@property(nonatomic, strong) UIActionSheet *itemActionSheet;
@property(nonatomic) NSInteger ejectButtonIndex;
@property(nonatomic) NSInteger renameButtonIndex;
@property(nonatomic) NSInteger moveCopyButtonIndex;
@property(nonatomic) NSInteger extractButtonIndex;
@property(nonatomic) NSInteger compressButtonIndex;
@property(nonatomic) NSInteger shareButtonIndex;
@property(nonatomic) NSInteger downloadButtonIndex;
@property(nonatomic) NSInteger openInButtonIndex;

/* Ads */
@property(nonatomic, strong) GADInterstitial *interstitial;

/* Space information */
@property(nonatomic, strong) UILabel *spaceInfo;

@property(nonatomic, strong) UIDocumentInteractionController* documentInteractionController;

@property(nonatomic, strong) NSMutableArray *photos;

@property(nonatomic, strong) UIRefreshControl *refreshControl;

/* CMDelegate protocol */
- (void)CMAction:(NSNotification*)notification;
- (void)CMLogin:(NSDictionary *)dict;
- (void)CMLogout:(NSDictionary *)dict;
- (void)CMRequestOTP:(NSNotification *)notification;
- (void)CMFilesList:(NSDictionary *)dict;
- (void)CMSpaceInfo:(NSNotification*)notification;
- (void)CMRename:(NSNotification*)notification;
- (void)CMDeleteFinished:(NSNotification*)notification;
- (void)CMCreateFolder:(NSDictionary *)dict;
- (void)CMCopyFinished:(NSNotification*)notification;
- (void)CMMoveFinished:(NSNotification*)notification;
- (void)CMEjectableList:(NSNotification*)notification;
- (void)CMEjectFinished:(NSNotification*)notification;
- (void)CMDownloadFinished:(NSNotification *)notification;
- (void)CMUploadProgress:(NSNotification*)notification;
- (void)CMUploadFinished:(NSNotification*)notification;
- (void)CMSearchFinished:(NSNotification *)notification;
- (void)CMShareProgress:(NSDictionary *)dict;
- (void)CMShareFinished:(NSDictionary *)dict;
- (void)CMConnectionError:(NSNotification*)notification;

/* SortingItemsController delegate */
- (void)selectedSortingType:(FileItemSortType)sortingType;
- (void)cancelSortingType;

/* CompressViewController delegate */
- (void)compressFiles:(NSArray *)files toArchive:(NSString *)archive archiveType:(ARCHIVE_TYPE)archiveType compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel password:(NSString *)password overwrite:(BOOL)overwrite;

/* ExtractViewController delegate */
- (void)extractFiles:(NSArray *)files toFolder:(FileItem *)folder withPassword:(NSString *)password overwrite:(BOOL)overwrite extractWithFolder:(BOOL)extractFolders;

/* MoveFileViewController delegate */
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;

/* UploadBrowserViewController delegate */
- (void)uploadFile:(FileItem *)file;

/* ShareViewController delegate */
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password;

/* common to several delegates */
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;

/* ChromeCast */
@property(nonatomic, strong) UIButton *chromecastButton;
@property(nonatomic, strong) UIActionSheet * gcActionSheet;
- (void)didDiscoverDeviceOnNetwork;
- (void)updateGCState;

@end
