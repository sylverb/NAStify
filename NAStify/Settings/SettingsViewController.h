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
#if TARGET_OS_IOS
#import "MKStoreKit.h"
#endif

// GoogleCast support
#if TARGET_OS_IOS
#import "GoogleCastController.h"
#endif

#if TARGET_OS_IOS
@interface SettingsViewController : UITableViewController <TableSelectViewControllerDelegate,UIActionSheetDelegate,GCControllerDelegate>
#elif TARGET_OS_TV
@interface SettingsViewController : UITableViewController <TableSelectViewControllerDelegate>
#endif
#if TARGET_OS_IOS
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
#elif TARGET_OS_TV
/* File sorting */
@property(nonatomic) FileItemSortType sortingType;
@property(nonatomic, strong) NSArray *sortingOptions;
@property(nonatomic) BOOL descending;
@property(nonatomic) BOOL foldersFirst;
@property(nonatomic) NSInteger selectedSortingOptionIndex;
#endif

@end
