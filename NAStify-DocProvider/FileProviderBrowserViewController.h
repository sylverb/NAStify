//
//  FileProviderBrowserViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DocumentPickerViewController.h"
#import "NSMutableArrayAdditions.h"
#import "ConnectionManager.h"
#import "FileBrowserCell.h"
#import "MBProgressHUD.h"
#import "UIPopoverController+iPhone.h"
#import "FileProviderViewController.h"

@interface FileProviderBrowserViewController : UIViewController <CMDelegate, UITableViewDataSource, UITableViewDelegate, MBProgressHUDDelegate>

@property(nonatomic, strong) DocumentPickerViewController *delegate;
@property(nonatomic, strong) NSArray *validTypes;

@property(nonatomic, strong) NSString *downloadFilename;

@property(nonatomic, strong) id <CM> connectionManager;

@property(nonatomic, strong) UserAccount *userAccount;

@property(nonatomic) ProviderMode mode;

@property(nonatomic, strong) NSURL *fileURL;

@property(nonatomic, strong) FileItem *currentFolder;

@property(nonatomic, strong) NSMutableArray *filesArray;

/* Logout handling */
@property(nonatomic) BOOL isConnected;

/* sorting handling */
@property(nonatomic) FileItemSortType sortingType;

/* Multiple Selection handling */
@property(nonatomic, strong) UITableView *tableView;

/* Action button sheet handling */
@property(nonatomic, strong) UIPopoverController *sortPopoverController;
@property(nonatomic, strong) UIActionSheet *actionSheet;
@property(nonatomic) NSInteger reloadActionButtonIndex;
@property(nonatomic) NSInteger serverInfoButtonIndex;

/* Space information */
@property(nonatomic, strong) UILabel *spaceInfo;

@property(nonatomic, strong) UIRefreshControl *refreshControl;

/* CMDelegate protocol */
- (void)CMAction:(NSNotification*)notification;
- (void)CMLogin:(NSDictionary *)dict;
- (void)CMLogout:(NSDictionary *)dict;
- (void)CMRequestOTP:(NSNotification *)notification;
- (void)CMFilesList:(NSDictionary *)dict;
- (void)CMSpaceInfo:(NSNotification*)notification;
- (void)CMDownloadProgress:(NSNotification *)notification;
- (void)CMDownloadFinished:(NSNotification *)notification;
- (void)CMConnectionError:(NSNotification*)notification;

@end
