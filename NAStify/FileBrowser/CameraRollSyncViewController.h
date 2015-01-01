//
//  CameraRollSyncViewController.h
//  NAStify
//
//  Created by Sylver Bruneau on 08/08/2014.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ConnectionManager.h"
#import "ELCImagePickerController.h"
#import "MBProgressHUD.h"

typedef enum {
    CameraRollSyncModeAlbum = 0,
    CameraRollSyncModePicker = 1
} CameraRollSyncMode;

@protocol CameraRollSyncViewDelegate
@optional
- (void)backFromModalView:(BOOL)refreshList;
@end

@interface CameraRollSyncViewController : UIViewController <CMDelegate,MBProgressHUDDelegate,UITableViewDataSource,UITableViewDelegate,ELCImagePickerControllerDelegate>

@property(nonatomic, strong) MBProgressHUD *hud;

@property(nonatomic, strong) UITableView *tableView;

@property(nonatomic, strong) ALAssetsLibrary *library;
@property(nonatomic, strong) id <CM> connectionManager;
@property(nonatomic, strong) id delegate;
//@property(nonatomic, strong) NSMutableDictionary *assetsDict;
@property(nonatomic, strong) NSMutableArray *assetItems;
@property(nonatomic, strong) FileItem *currentFolder;

@property(nonatomic, strong) NSMutableArray *filesArray;

@property(nonatomic) CameraRollSyncMode mode;

@property(nonatomic) NSInteger filesTotal;
@property(nonatomic) NSInteger filesCount;
@property(nonatomic) BOOL allAlbumsSelected;
@property(nonatomic) BOOL parsePhotos;
@property(nonatomic) BOOL parseVideos;
@property(nonatomic) BOOL parsingOnProgress;
@property(nonatomic) BOOL uploadOnProgress;
@property(nonatomic, strong) NSMutableArray *groupsArray;
@property(nonatomic, strong) NSMutableDictionary *selectedGroupsDict;

/* Buttons */
@property(nonatomic, strong) UIBarButtonItem *uploadButtonItem;

/* Progress views */
@property(nonatomic, strong) MBProgressHUD *progressHUD;

/* CMDelegate protocol */
- (void)CMFilesList:(NSDictionary *)dict;
- (void)CMRootObject:(NSDictionary *)dict;
- (void)CMUploadProgress:(NSDictionary *)dict;
- (void)CMUploadFinished:(NSDictionary *)dict;

@end
