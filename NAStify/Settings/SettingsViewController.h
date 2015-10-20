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
