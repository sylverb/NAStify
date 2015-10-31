//
//  FileBrowserViewController.h
//  NAStify-tvOS
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2015 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ConnectionManager.h"
#import "FileBrowserCell.h"
#import "NSMutableArrayAdditions.h"
#import "NSNumberAdditions.h"

typedef enum
{
    DOWNLOAD_ACTION_DOWNLOAD,
    DOWNLOAD_ACTION_SUBTITLE,
    DOWNLOAD_ACTION_PREVIEW,
} DOWNLOAD_ACTION;

@interface FileBrowserViewController : UITableViewController <CMDelegate, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UINavigationBarDelegate>
{
}

@property(nonatomic, strong) id <CM> connectionManager;

@property(nonatomic, strong) UserAccount *userAccount;

@property(nonatomic, strong) FileItem *currentFolder;

@property(nonatomic, strong) NSMutableArray *filesArray;
@property(nonatomic, strong) NSMutableArray *filteredFilesArray;
@property(nonatomic) BOOL filesListIsValid;


/* Multiple Selection handling */
//@property(nonatomic, strong) UITableView *multipleSelectionTableView;

/* sorting handling */
@property(nonatomic) FileItemSortType sortingType;

/* Logout handling */
@property(nonatomic) BOOL isConnected;

/* Downloading handling */
@property(nonatomic, strong) FileItem *videoFile;
@property(nonatomic) DOWNLOAD_ACTION downloadAction;
@property(nonatomic, strong) FileItem *sourceFileItem;
@property(nonatomic, strong) NSString *dlFilePath;
@property(nonatomic, strong) NSString *videoUrl;

/* Space information */
@property(nonatomic, strong) UILabel *spaceInfo;

/* CMDelegate protocol */
- (void)CMLogin:(NSDictionary *)dict;
- (void)CMLogout:(NSDictionary *)dict;
- (void)CMRequestOTP:(NSNotification *)notification;
- (void)CMFilesList:(NSDictionary *)dict;
- (void)CMRootObject:(NSDictionary *)dict;
- (void)CMAction:(NSNotification*)notification;
- (void)CMCredentialRequest:(NSDictionary *)dict;
- (void)CMConnectionError:(NSNotification*)notification;

@end
