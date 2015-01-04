//
//  SettingsViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VlcSettingsViewController.h"
#import "TableSelectViewController.h"

// In APP Purchase
#import <StoreKit/StoreKit.h>
#import "MKStoreKit.h"

// GoogleCast support
#import "GoogleCastController.h"

#define kNASTifySettingBrowserShowGCast     @"BrowserShowGCast"
#define kNASTifySettingPlayerType           @"VideoPlayerType"
#define kNASTifySettingPlayerTypeInternal           0
#define kNASTifySettingPlayerTypeExternal           1
#define kNASTifySettingInternalPlayer       @"VideoPlayer"
#define kNASTifySettingInternalPlayerTypeQTVLC      0
#define kNASTifySettingInternalPlayerTypeVLCOnly    1
#define kNASTifySettingExternalPlayer       @"ExternalVideoPlayer"
#define kNASTifySettingExternalPlayerType   @"ExternalVideoPlayerType"
#define kNASTifySettingExternalPlayerTypeVlc        0
#define kNASTifySettingExternalPlayerTypeAceplayer  1
#define kNASTifySettingExternalPlayerTypeGplayer    2
#define kNASTifySettingExternalPlayerTypeOplayer    3
#define kNASTifySettingExternalPlayerTypeGoodplayer 4
#define kNASTifySettingExternalPlayerTypePlex       5

@interface SettingsViewController : UITableViewController <TableSelectViewControllerDelegate,UIActionSheetDelegate,GCControllerDelegate>

@property (nonatomic, strong) NSArray *delayOptions;
@property (nonatomic, strong) NSArray *delayShortOptions;
@property (nonatomic, strong) NSArray *delayValues;
@property (nonatomic) NSInteger delayIndex;

/* Touch ID */
@property (nonatomic) BOOL isTouchIDPresent;

/* ChromeCast */

@property(nonatomic, strong) GoogleCastController *gcController;
@property(nonatomic, strong) UIActionSheet * gcActionSheet;
- (void)didDiscoverDeviceOnNetwork;
- (void)updateGCState;

@end
