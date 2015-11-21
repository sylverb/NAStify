//
//  SettingsViewController.m
//  NAStify
//
//  Created by Sylver Bruneau on 16/04/2014.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "SettingsViewController.h"
#import "SegCtrlCell.h"
#import "TextCell.h"
#if TARGET_OS_IOS
#import "SwitchCell.h"
#import "SDImageCache.h"
#import "LTHPasscodeViewController.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "AboutViewController.h"
#import "SKProduct+priceAsString.h"
#import "MAConfirmButton.h"
#import "SBNetworkActivityIndicator.h"
#import "PurchaseServerViewController.h"
#endif

#if TARGET_OS_IOS
#define SETTINGS_PURCHASE_SECTION_INDEX 0
#define SETTINGS_ABOUT_SECTION_INDEX 1
#define SETTINGS_FILEBROWSER_SECTION_INDEX 2
#define SETTINGS_MEDIA_PLAYER_TYPE_SECTION_INDEX 3
#define SETTINGS_MEDIA_PLAYER_INTERNAL_SECTION_INDEX 4
#define SETTINGS_MEDIA_PLAYER_EXTERNAL_SECTION_INDEX 5
#define SETTINGS_PASSCODE_SECTION_INDEX 6
#define SETTINGS_GCAST_SECTION_INDEX 7
#elif TARGET_OS_TV
//#define SETTINGS_ABOUT_SECTION_INDEX 1
#define SETTINGS_FILEBROWSER_SECTION_INDEX 0
#define SETTINGS_MEDIA_PLAYER_INTERNAL_SECTION_INDEX 1
#endif
#define TAG_BROWSER_GCAST       0
#define TAG_MEDIA_PLAYER        1
#define TAG_MEDIA_PLAYER_TYPE   2
#define TAG_SIMPLECODE          3
#define TAG_CODEDELAY           4
#define TAG_TOUCHID             5
#define TAG_SORTING_TYPE        6

@interface SettingsViewController ()

@end

@implementation SettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self)
    {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Settings", nil);
    
#if TARGET_OS_IOS
    NSInteger index;
    // Require Passcode : Immediately, After 1 minute, After 5 minutes, After 15 minutes, After 1 hour, After 4 hours
    self.delayOptions = [NSArray arrayWithObjects:
                         NSLocalizedString(@"Immediately", nil),
                         NSLocalizedString(@"After 1 minute", nil),
                         NSLocalizedString(@"After 5 minutes", nil),
                         NSLocalizedString(@"After 15 minutes", nil),
                         NSLocalizedString(@"After 1 hour", nil),
                         NSLocalizedString(@"After 4 hours", nil),
                         nil];
    self.delayShortOptions = [NSArray arrayWithObjects:
                              NSLocalizedString(@"Immediately", nil),
                              NSLocalizedString(@"After 1 min.", nil),
                              NSLocalizedString(@"After 5 min.", nil),
                              NSLocalizedString(@"After 15 min.", nil),
                              NSLocalizedString(@"After 1 hour", nil),
                              NSLocalizedString(@"After 4 hours", nil),
                         nil];
    self.delayValues = [NSArray arrayWithObjects:
                        [NSNumber numberWithInteger:0],
                        [NSNumber numberWithInteger:60],
                        [NSNumber numberWithInteger:5*60],
                        [NSNumber numberWithInteger:15*60],
                        [NSNumber numberWithInteger:60*60],
                        [NSNumber numberWithInteger:4*60*60],
                        nil];
    self.delayIndex = 0;
    for (index = 0;index <[self.delayValues count];index++)
    {
        if ([[self.delayValues objectAtIndex:index] longValue] == [LTHPasscodeViewController timerDuration])
        {
            self.delayIndex = index;
            break;
        }
    }
    
    self.gcController = [GoogleCastController sharedGCController];
    // Touch ID detection
    self.isTouchIDPresent = NO;
    
    LAContext   *context = [[LAContext alloc] init];
    NSError *error = nil;
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
        if (!error) {
            self.isTouchIDPresent = YES;
        }
    }
    
    // In-App purchase management
    [[NSNotificationCenter defaultCenter] addObserverForName:kMKStoreKitProductsAvailableNotification
                                                      object:nil
                                                       queue:[[NSOperationQueue alloc] init]
                                                  usingBlock:^(NSNotification *note) {
                                                      // End the network activity spinner
                                                      [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

                                                      for (SKProduct *product in [[MKStoreKit sharedKit] availableProducts])
                                                      {
                                                          NSLog(@"Title: %@\nDescription: %@\nPrice: %@\n",product.localizedTitle,product.localizedDescription,[product priceAsString]);
                                                          dispatch_async(dispatch_get_main_queue(), ^{
                                                              [self.tableView reloadData];
                                                          });
                                                      }
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kMKStoreKitProductPurchasedNotification
                                                      object:nil
                                                       queue:[[NSOperationQueue alloc] init]
                                                  usingBlock:^(NSNotification *note) {
                                                      // End the network activity spinner
                                                      [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

                                                      NSLog(@"Purchased/Subscribed to product with id: %@", [note object]);
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          [self.tableView reloadData];
                                                      });
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kMKStoreKitProductPurchaseFailedNotification
                                                      object:nil
                                                       queue:[[NSOperationQueue alloc] init]
                                                  usingBlock:^(NSNotification *note) {
                                                      // End the network activity spinner
                                                      [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                                                      
                                                      SKPaymentTransaction *transaction = (SKPaymentTransaction *)note.object;
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                                                      message:transaction.error.localizedDescription
                                                                                     delegate:nil
                                                                            cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                                            otherButtonTitles: nil] show];
                                                          
                                                          [self.tableView reloadData];
                                                      });
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kMKStoreKitRestoredPurchasesNotification
                                                      object:nil
                                                       queue:[[NSOperationQueue alloc] init]
                                                  usingBlock:^(NSNotification *note) {
                                                      // End the network activity spinner
                                                      [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

                                                      NSLog(@"Restored Purchases");
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Info", nil)
                                                                                      message:NSLocalizedString(@"Purchase(s) restored", nil)
                                                                                     delegate:nil
                                                                            cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                                            otherButtonTitles: nil] show];
                                                          
                                                          [self.tableView reloadData];
                                                      });
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kMKStoreKitRestoringPurchasesFailedNotification
                                                      object:nil
                                                       queue:[[NSOperationQueue alloc] init]
                                                  usingBlock:^(NSNotification *note) {
                                                      // End the network activity spinner
                                                      [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

                                                      NSLog(@"Failed restoring purchases with error: %@", [note object]);
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          [self.tableView reloadData];
                                                      });
                                                  }];
#endif
#if TARGET_OS_TV
    // Init sorting type info
    self.foldersFirst = NO;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    
    if ([defaults objectForKey:@"showHidden"])
    {
        self.showHidden = [[defaults objectForKey:@"showHidden"] boolValue];
    }
    else
    {
        self.showHidden = NO;
    }

    if ([defaults objectForKey:@"sortingType"])
    {
        self.sortingType = (FileItemSortType)[[defaults objectForKey:@"sortingType"] integerValue];
    }
    else
    {
        self.sortingType = SORT_BY_NAME_DESC_FOLDER_FIRST;
    }

    switch (self.sortingType)
    {
        case SORT_BY_NAME_DESC_FOLDER_FIRST:
        {
            self.selectedSortingOptionIndex = 0;
            self.foldersFirst = YES;
            self.descending = YES;
            break;
        }
        case SORT_BY_NAME_DESC:
        {
            self.selectedSortingOptionIndex = 0;
            self.foldersFirst = NO;
            self.descending = YES;
            break;
        }
        case SORT_BY_NAME_ASC_FOLDER_FIRST:
        {
            self.selectedSortingOptionIndex = 0;
            self.foldersFirst = YES;
            self.descending = NO;
            break;
        }
        case SORT_BY_NAME_ASC:
        {
            self.selectedSortingOptionIndex = 0;
            self.foldersFirst = NO;
            self.descending = NO;
            break;
        }
        case SORT_BY_DATE_DESC_FOLDER_FIRST:
        {
            self.selectedSortingOptionIndex = 1;
            self.foldersFirst = YES;
            self.descending = YES;
            break;
        }
        case SORT_BY_DATE_DESC:
        {
            self.selectedSortingOptionIndex = 1;
            self.foldersFirst = NO;
            self.descending = YES;
            break;
        }
        case SORT_BY_DATE_ASC_FOLDER_FIRST:
        {
            self.selectedSortingOptionIndex = 1;
            self.foldersFirst = YES;
            self.descending = NO;
            break;
        }
        case SORT_BY_DATE_ASC:
        {
            self.selectedSortingOptionIndex = 1;
            self.foldersFirst = NO;
            self.descending = NO;
            break;
        }
        case SORT_BY_TYPE_DESC_FOLDER_FIRST:
        {
            self.selectedSortingOptionIndex = 2;
            self.foldersFirst = YES;
            self.descending = YES;
            break;
        }
        case SORT_BY_TYPE_DESC:
        {
            self.selectedSortingOptionIndex = 2;
            self.foldersFirst = NO;
            self.descending = YES;
            break;
        }
        case SORT_BY_TYPE_ASC_FOLDER_FIRST:
        {
            self.selectedSortingOptionIndex = 2;
            self.foldersFirst = YES;
            self.descending = NO;
            break;
        }
        case SORT_BY_TYPE_ASC:
        {
            self.selectedSortingOptionIndex = 2;
            self.foldersFirst = NO;
            self.descending = NO;
            break;
        }
        case SORT_BY_SIZE_DESC_FOLDER_FIRST:
        {
            self.selectedSortingOptionIndex = 3;
            self.foldersFirst = YES;
            self.descending = YES;
            break;
        }
        case SORT_BY_SIZE_DESC:
        {
            self.selectedSortingOptionIndex = 3;
            self.foldersFirst = NO;
            self.descending = YES;
            break;
        }
        case SORT_BY_SIZE_ASC_FOLDER_FIRST:
        {
            self.selectedSortingOptionIndex = 3;
            self.foldersFirst = YES;
            self.descending = NO;
            break;
        }
        case SORT_BY_SIZE_ASC:
        {
            self.selectedSortingOptionIndex = 3;
            self.foldersFirst = NO;
            self.descending = NO;
            break;
        }
        default:
        {
            break;
        }
    }
    
    self.sortingOptions = [NSArray arrayWithObjects:
                           NSLocalizedString(@"name", nil),
                           NSLocalizedString(@"date", nil),
                           NSLocalizedString(@"type", nil),
                           NSLocalizedString(@"size", nil),
                           nil];
#endif
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
#if TARGET_OS_IOS
    self.gcController.delegate = self;
#endif
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 8;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    //FIXME: implement filebrowser options
    // Return the number of rows in the section.
    NSInteger numberOfRows = 0;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    
    switch (section)
    {
        case SETTINGS_FILEBROWSER_SECTION_INDEX:
        {
#if TARGET_OS_IOS
            numberOfRows = 1;
#elif TARGET_OS_TV
            numberOfRows = 5;
#endif
            break;
        }
#if TARGET_OS_IOS
        case SETTINGS_MEDIA_PLAYER_TYPE_SECTION_INDEX:
        {
            numberOfRows = 1;
            break;
        }
#endif
        case SETTINGS_MEDIA_PLAYER_INTERNAL_SECTION_INDEX:
        {
            if ([[defaults objectForKey:kNASTifySettingPlayerType] integerValue] == kNASTifySettingPlayerTypeInternal)
            {
                numberOfRows = 2;
            }
            break;
        }
#if TARGET_OS_IOS
        case SETTINGS_MEDIA_PLAYER_EXTERNAL_SECTION_INDEX:
        {
            if ([[defaults objectForKey:kNASTifySettingPlayerType] integerValue] == kNASTifySettingPlayerTypeExternal)
            {
                numberOfRows = 5;
            }
            break;
        }
        case SETTINGS_PASSCODE_SECTION_INDEX:
        {
            if (self.isTouchIDPresent)
            {
                numberOfRows = 5;
            }
            else
            {
                numberOfRows = 4;
            }
            break;
        }
        case SETTINGS_GCAST_SECTION_INDEX:
        {
            if (self.gcController.deviceScanner.devices.count > 0)
            {
                numberOfRows = 2;
            }
            else
            {
                numberOfRows = 1;
            }
            break;
        }
        case SETTINGS_ABOUT_SECTION_INDEX:
        {
            numberOfRows = 3;
            break;
        }
        case SETTINGS_PURCHASE_SECTION_INDEX:
        {
            if ([MKStoreKit sharedKit].availableProducts.count > 0)
            {
                if ([[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads"])
                {
                    numberOfRows = 2;
                }
                else
                {
                    numberOfRows = 3;
                }
            }
        }
#endif
        default:
        {
            break;
        }
    }
    return numberOfRows;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString * title = nil;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    
    switch (section)
    {
        case SETTINGS_FILEBROWSER_SECTION_INDEX:
        {
            title = NSLocalizedString(@"File Browser",nil);
            break;
        }
#if TARGET_OS_IOS
        case SETTINGS_MEDIA_PLAYER_TYPE_SECTION_INDEX:
        {
            title = NSLocalizedString(@"Media player Selection",nil);
            break;
        }
#endif
        case SETTINGS_MEDIA_PLAYER_INTERNAL_SECTION_INDEX:
        {
            if ([[defaults objectForKey:kNASTifySettingPlayerType] integerValue] == kNASTifySettingPlayerTypeInternal)
            {
#if TARGET_OS_IOS
                title = NSLocalizedString(@"Internal media player",nil);
#elif TARGET_OS_TV
                title = NSLocalizedString(@"Media player configuration",nil);
#endif
            }
            break;
        }
#if TARGET_OS_IOS
        case SETTINGS_MEDIA_PLAYER_EXTERNAL_SECTION_INDEX:
        {
            if ([[defaults objectForKey:kNASTifySettingPlayerType] integerValue] == kNASTifySettingPlayerTypeExternal)
            {
                title = NSLocalizedString(@"External media player",nil);
            }
            break;
        }
        case SETTINGS_PASSCODE_SECTION_INDEX:
        {
            title = NSLocalizedString(@"Passcode Lock",nil);
            break;
        }
        case SETTINGS_GCAST_SECTION_INDEX:
        {
            title = NSLocalizedString(@"Google Cast",nil);
            break;
        }
        case SETTINGS_ABOUT_SECTION_INDEX:
        {
            title = NSLocalizedString(@"About",nil);
            break;
        }
        case SETTINGS_PURCHASE_SECTION_INDEX:
        {
            if ([MKStoreKit sharedKit].availableProducts.count > 0)
            {
                title = NSLocalizedString(@"In-App Purchases", nil);
            }
            break;
        }
#endif
    }
    return title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
#if TARGET_OS_IOS
    static NSString *TextCellIdentifier = @"TextCell";
    static NSString *SegmentedControllerCell1Identifier = @"SegmentedControllerCell1";
	static NSString *SwitchCellIdentifier = @"SwitchCell";
    static NSString *PurchaseCellIdentifier = @"PurchaseCell";
    static NSString *SegmentedControllerCell2Identifier = @"SegmentedControllerCell2";
#endif
#if TARGET_OS_TV
    static NSString *CellIdentifier1 = @"CellValue1";
#endif
    UITableViewCell *cell = nil;
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    
    switch (indexPath.section)
    {
        case SETTINGS_FILEBROWSER_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
#if TARGET_OS_IOS
                case 0:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    // Configure the cell...
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.textColor = [UIColor blackColor];
                    cell.textLabel.text = [NSString stringWithFormat:@"Clear Photo Cache (%ld MB)",(long)([[SDImageCache sharedImageCache] getSize]/(1024*1024))];
                    
                    break;
                }
#elif TARGET_OS_TV
                case 0:
                {
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Sort by",nil);
                    cell.detailTextLabel.text = [self.sortingOptions objectAtIndex:self.selectedSortingOptionIndex];
                    break;
                }
                case 1:
                {
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Folders first",nil);
                    if (self.foldersFirst)
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"Yes", nil);
                    }
                    else
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"No", nil);
                    }
                    break;
                }
                case 2:
                {
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Order",nil);
                    if (self.descending)
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"Descending", nil);
                    }
                    else
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"Ascending", nil);
                    }
                    break;
                }
                case 3:
                {
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Show hidden files",nil);
                    if (self.showHidden)
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"Yes", nil);
                    }
                    else
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"No", nil);
                    }
                    break;
                }
                case 4:
                {
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"File browser type",nil);
                    if ([[defaults objectForKey:kNASTifySettingBrowserType] integerValue] == kNASTifySettingBrowserTypeGrid)
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"Grid", nil);
                    }
                    else
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"Line", nil);
                    }
                    break;
                }
#endif
                default:
                {
                    break;
                }
            }
            break;
        }
#if TARGET_OS_IOS
        case SETTINGS_MEDIA_PLAYER_TYPE_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    SegCtrlCell *segCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedControllerCell1Identifier];
                    if (segCtrlCell == nil)
                    {
                        segCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:SegmentedControllerCell1Identifier
                                                               withItems:[NSArray arrayWithObjects:
                                                                          NSLocalizedString(@"Internal",nil),
                                                                          NSLocalizedString(@"External",nil),
                                                                          nil]];
                    }
                    
                    [segCtrlCell setCellDataWithLabelString:NSLocalizedString(@"Media player:",nil)
                                          withSelectedIndex:[[defaults objectForKey:kNASTifySettingPlayerType] integerValue]
                                                     andTag:TAG_MEDIA_PLAYER_TYPE];
                    
                    [segCtrlCell.segmentedControl addTarget:self action:@selector(segmentedValueChanged:) forControlEvents:UIControlEventValueChanged];
                    
                    cell = segCtrlCell;
                    
                    break;
                }
                default:
                {
                    break;
                }
            }
            break;
        }
#endif
        case SETTINGS_MEDIA_PLAYER_INTERNAL_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
#if TARGET_OS_IOS
                    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
                    
                    SegCtrlCell *segCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedControllerCell2Identifier];
                    if (segCtrlCell == nil)
                    {
                        segCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:SegmentedControllerCell2Identifier
                                                               withItems:[NSArray arrayWithObjects:
                                                                          NSLocalizedString(@"QT+VLC",nil),
                                                                          NSLocalizedString(@"VLC Only",nil),
                                                                          nil]];
                    }
                    
                    [segCtrlCell setCellDataWithLabelString:NSLocalizedString(@"Media player:",nil)
                                          withSelectedIndex:[[defaults objectForKey:kNASTifySettingInternalPlayer] integerValue]
                                                     andTag:TAG_MEDIA_PLAYER];
                    
                    [segCtrlCell.segmentedControl addTarget:self action:@selector(segmentedValueChanged:) forControlEvents:UIControlEventValueChanged];
                    
                    cell = segCtrlCell;
#else
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Media Player",nil);
                    if ([[defaults objectForKey:kNASTifySettingInternalPlayer] integerValue] == kNASTifySettingInternalPlayerTypeQTVLC)
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"QuickTime Player and VLC", nil);
                    }
                    else
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"VLC Only", nil);
                    }
#endif
                    break;
                }
                case 1:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    // Configure the cell...
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.textColor = [UIColor blackColor];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.textLabel.text = NSLocalizedString(@"Internal VLC settings",nil);
                    
                    break;
                }
                default:
                {
                    break;
                }
            }
            break;
        }
#if TARGET_OS_IOS
        case SETTINGS_MEDIA_PLAYER_EXTERNAL_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.textLabel.text = @"VLC";
                    cell.textLabel.contentMode = UIViewContentModeCenter;
                    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"vlc://"]])
                    {
                        cell.textLabel.textColor = [UIColor blackColor];
                    }
                    else
                    {
                        cell.textLabel.textColor = [UIColor grayColor];
                    }
                    
                    if ([[defaults objectForKey:kNASTifySettingExternalPlayerType] integerValue] == kNASTifySettingExternalPlayerTypeVlc)
                    {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    }
                    else
                    {
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    break;
                }
                case 1:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.textLabel.text = @"AcePlayer";
                    cell.textLabel.contentMode = UIViewContentModeCenter;
                    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"aceplayer://"]])
                    {
                        cell.textLabel.textColor = [UIColor blackColor];
                    }
                    else
                    {
                        cell.textLabel.textColor = [UIColor grayColor];
                    }
                    
                    if ([[defaults objectForKey:kNASTifySettingExternalPlayerType] integerValue] == kNASTifySettingExternalPlayerTypeAceplayer)
                    {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    }
                    else
                    {
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    break;
                }
                case 2:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.textLabel.text = @"GPlayer";
                    cell.textLabel.contentMode = UIViewContentModeCenter;
                    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"gplayer://"]])
                    {
                        cell.textLabel.textColor = [UIColor blackColor];
                    }
                    else
                    {
                        cell.textLabel.textColor = [UIColor grayColor];
                    }
                    
                    if ([[defaults objectForKey:kNASTifySettingExternalPlayerType] integerValue] == kNASTifySettingExternalPlayerTypeGplayer)
                    {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    }
                    else
                    {
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    break;
                }
                case 3:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.textLabel.text = @"OPlayer";
                    cell.textLabel.contentMode = UIViewContentModeCenter;
                    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"oplayer://"]])
                    {
                        cell.textLabel.textColor = [UIColor blackColor];
                    }
                    else
                    {
                        cell.textLabel.textColor = [UIColor grayColor];
                    }
                    
                    if ([[defaults objectForKey:kNASTifySettingExternalPlayerType] integerValue] == kNASTifySettingExternalPlayerTypeOplayer)
                    {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    }
                    else
                    {
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    break;
                }
                case 4:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.textLabel.text = @"GoodPlayer";
                    cell.textLabel.contentMode = UIViewContentModeCenter;
                    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"goodplayer://"]])
                    {
                        cell.textLabel.textColor = [UIColor blackColor];
                    }
                    else
                    {
                        cell.textLabel.textColor = [UIColor grayColor];
                    }
                    
                    if ([[defaults objectForKey:kNASTifySettingExternalPlayerType] integerValue] == kNASTifySettingExternalPlayerTypeGoodplayer)
                    {
                        cell.accessoryType = UITableViewCellAccessoryCheckmark;
                    }
                    else
                    {
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    break;
                }
                default:
                {
                    break;
                }
            }
            break;
        }
        case SETTINGS_PASSCODE_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.textColor = [UIColor blackColor];
                    if ([LTHPasscodeViewController doesPasscodeExist])
                    {
                        cell.textLabel.text = @"Turn Passcode Off";
                    }
                    else
                    {
                        cell.textLabel.text = @"Turn Passcode On";
                    }
                    
                    break;
                }
                case 1:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.accessoryType = UITableViewCellAccessoryNone;

                    cell.textLabel.text = @"Change Passcode";
                    if ([LTHPasscodeViewController doesPasscodeExist])
                    {
                        cell.textLabel.textColor = [UIColor blackColor];
                    }
                    else
                    {
                        cell.textLabel.textColor = [UIColor lightGrayColor];
                    }
                    
                    break;
                }
                case 2:
                {
                    TextCell *textCell = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCell == nil)
                    {
                        textCell = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                      reuseIdentifier:TextCellIdentifier];
                    }
                    [textCell setCellDataWithLabelString:NSLocalizedString(@"Require Passcode", nil)
                                                withText:[self.delayShortOptions objectAtIndex:self.delayIndex]
                                         withPlaceHolder:nil
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeDefault
                                            withDelegate:nil
                                                  andTag:0];
                    textCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    textCell.textField.enabled = NO;
                    cell = textCell;
                    break;
                }
                case 3:
                {
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil)
                    {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell setCellDataWithLabelString:NSLocalizedString(@"Simple Passcode",nil)
                                                 withState:[[LTHPasscodeViewController sharedUser] isSimple]
                                                    andTag:TAG_SIMPLECODE];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
                    
                    break;
                }
                case 4:
                {
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil)
                    {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell setCellDataWithLabelString:NSLocalizedString(@"Allow unlock with Touch ID",nil)
                                                 withState:[[LTHPasscodeViewController sharedUser] allowUnlockWithTouchID]
                                                    andTag:TAG_TOUCHID];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
                    break;
                }
            }
            break;
        }
        case SETTINGS_GCAST_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil)
                    {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell setCellDataWithLabelString:NSLocalizedString(@"Show Google Cast icon",nil)
                                                 withState:[[defaults objectForKey:kNASTifySettingBrowserShowGCast] boolValue]
                                                    andTag:TAG_BROWSER_GCAST];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
                    
                    break;
                }
                case 1:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    // Configure the cell...
                    if (self.gcController.isConnected)
                    {
                        cell.accessoryType = UITableViewCellAccessoryNone;
                        cell.textLabel.textColor = [UIColor blackColor];
                        cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Disconnect from \"%@\"",nil),
                                               self.gcController.selectedDevice.friendlyName];
                    }
                    else
                    {
                        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                        cell.textLabel.textColor = [UIColor blackColor];
                        cell.textLabel.text = NSLocalizedString(@"Connect to Google Cast",nil);
                    }
                    
                    break;
                }
                default:
                {
                    break;
                }
            }
            break;
        }
        case SETTINGS_ABOUT_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.textLabel.textColor = [UIColor blackColor];
                    cell.textLabel.text = NSLocalizedString(@"About NAStify",nil);
                    break;
                }
                case 1:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.textColor = [UIColor blackColor];
                    cell.textLabel.text = NSLocalizedString(@"Report a bug/Feature request",nil);
                    break;
                }
                case 2:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.textColor = [UIColor blackColor];
                    cell.textLabel.text = NSLocalizedString(@"Tell your friends about NAStify",nil);
                    break;
                }
            }
            break;
        }
        case SETTINGS_PURCHASE_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.accessoryType = UITableViewCellAccessoryDetailButton;
                    cell.textLabel.textColor = [UIColor blackColor];
                    cell.textLabel.text = NSLocalizedString(@"Restore purchases", nil);
                    break;
                }
                case 1:
                {
                    SKProduct *product = [[MKStoreKit sharedKit].availableProducts objectAtIndex:0]; // com.sylver.NAStify.no_ads
                    
                    cell = [tableView dequeueReusableCellWithIdentifier:PurchaseCellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:PurchaseCellIdentifier];
                        
                        MAConfirmButton *defaultButton = nil;
                        
                        if ([[MKStoreKit sharedKit] isProductPurchased:product.productIdentifier])
                        {
                            defaultButton = [MAConfirmButton buttonWithDisabledTitle:NSLocalizedString(@"Confirmed",nil)];
                        }
                        else
                        {
                            defaultButton = [MAConfirmButton buttonWithTitle:product.priceAsString
                                                                     confirm:NSLocalizedString(@"Buy now",nil)];
                        }
                        [defaultButton setAnchor:CGPointMake(270, 10)];
                        [defaultButton addTarget:self action:@selector(confirmAction:) forControlEvents:UIControlEventTouchUpInside];
                        defaultButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                        
                        defaultButton.tag = indexPath.row - 1;
                        [cell addSubview:defaultButton];
                    }
                    else
                    {
                        MAConfirmButton *defaultButton = nil;
                        NSArray *subviews = [cell subviews];
                        for (UIView *subview in subviews)
                        {
                            if ([subview isKindOfClass:[MAConfirmButton class]])
                            {
                                defaultButton = (MAConfirmButton *)subview;
                                break;
                            }
                            
                        }
                        if ([[MKStoreKit sharedKit] isProductPurchased:product.productIdentifier])
                        {
                            [defaultButton disableWithTitle:NSLocalizedString(@"Confirmed",nil)];
                            defaultButton = [MAConfirmButton buttonWithDisabledTitle:NSLocalizedString(@"Confirmed",nil)];
                        }
                        else
                        {
                            [defaultButton enableWithTitle:product.priceAsString
                                                   confirm:NSLocalizedString(@"Buy now",nil)];
                        }
                        defaultButton.tag = indexPath.row - 1;
                    }
                    
                    cell.textLabel.textColor = [UIColor blackColor];
                    if ([[MKStoreKit sharedKit] isProductPurchased:product.productIdentifier])
                    {
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    else
                    {
                        cell.accessoryType = UITableViewCellAccessoryDetailButton;
                    }
                    cell.textLabel.text = product.localizedTitle;
                    break;
                }
                case 2:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    cell.textLabel.textColor = [UIColor blackColor];
                    cell.textLabel.text = NSLocalizedString(@"Remove Ads for specific server", nil);
                    break;
                }
            }
            break;
        }
#endif
        default:
        {
            break;
        }
    }
    return cell;
}

#if TARGET_OS_IOS
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section)
    {
        case SETTINGS_PURCHASE_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Info", nil)
                                                message:NSLocalizedString(@"Restore previous purchases", nil)
                                               delegate:nil
                                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                      otherButtonTitles: nil] show];
                    break;
                }
                case 1:
                {
                    SKProduct *product = [[MKStoreKit sharedKit].availableProducts objectAtIndex:0];
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Info", nil)
                                                message:product.localizedDescription
                                               delegate:nil
                                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                      otherButtonTitles: nil] show];
                    break;
                }
            }
            break;
        }
    }
}
#endif

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (indexPath.section)
    {
        case SETTINGS_FILEBROWSER_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
#if TARGET_OS_IOS
                case 0:
                {
                    [[SDImageCache sharedImageCache] clearDisk];
                    [[SDImageCache sharedImageCache] clearMemory];
                    [self.tableView reloadData];
                    break;
                }
#elif TARGET_OS_TV
                case 0:
                {
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Sort by",nil)
                                                                                   message:nil
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    
                    NSInteger index = 0;
                    for (NSString *element in self.sortingOptions)
                    {
                        UIAlertAction *action = [UIAlertAction actionWithTitle:element
                                                                         style:UIAlertActionStyleDefault
                                                                       handler:^(UIAlertAction * action) {
                                                                           self.selectedSortingOptionIndex = index;
                                                                           [alert dismissViewControllerAnimated:YES completion:nil];
                                                                           [self.tableView reloadData];
                                                                       }];
                        [alert addAction:action];
                        if (index == self.selectedSortingOptionIndex)
                        {
                            alert.preferredAction = action;
                        }
                        index++;
                    }
                    [self presentViewController:alert animated:YES completion:nil];
                    break;
                }
                case 1:
                {
                    self.foldersFirst = !self.foldersFirst;
                    [self saveSorting];
                    [self.tableView reloadData];
                    break;
                }
                case 2:
                {
                    self.descending = !self.descending;
                    [self saveSorting];
                    [self.tableView reloadData];
                    break;
                }
                case 3:
                {
                    self.showHidden = !self.showHidden;
                    [defaults setBool:self.showHidden forKey:@"showHidden"];
                    [self.tableView reloadData];
                    break;
                }
                case 4:
                {
                    if ([[defaults objectForKey:kNASTifySettingBrowserType] integerValue] == kNASTifySettingBrowserTypeGrid)
                    {
                        [defaults setObject:@(kNASTifySettingBrowserTypeLine) forKey:kNASTifySettingBrowserType];
                    }
                    else
                    {
                        [defaults setObject:@(kNASTifySettingBrowserTypeGrid) forKey:kNASTifySettingBrowserType];
                    }
                    [self.tableView reloadData];
                    break;
                }
#endif
            }
            break;
        }
        case SETTINGS_MEDIA_PLAYER_INTERNAL_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
#if TARGET_OS_TV
                case 0:
                {
                    switch ([[defaults objectForKey:kNASTifySettingInternalPlayer] integerValue])
                    {
                        case kNASTifySettingInternalPlayerTypeQTVLC:
                        {
                            [defaults setObject:[NSNumber numberWithLong:kNASTifySettingInternalPlayerTypeVLCOnly]
                                         forKey:kNASTifySettingInternalPlayer];
                            break;
                        }
                        case kNASTifySettingInternalPlayerTypeVLCOnly:
                        {
                            [defaults setObject:[NSNumber numberWithLong:kNASTifySettingInternalPlayerTypeQTVLC]
                                         forKey:kNASTifySettingInternalPlayer];
                            break;
                        }
                    }
                    [self.tableView reloadData];

                    break;
                }
#endif
                case 1:
                {
                    VlcSettingsViewController *viewController;
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                    {
                        viewController = [[VlcSettingsViewController alloc] initWithStyle:UITableViewStylePlain];
                    }
                    else
                    {
                        viewController = [[VlcSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
                    }
                    
                    [self.navigationController pushViewController:viewController animated:YES];
                    break;
                }
            }
            break;
        }
#if TARGET_OS_IOS
        case SETTINGS_MEDIA_PLAYER_EXTERNAL_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0: // VLC
                {
                    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"vlc://"]])
                    {
                        [defaults setObject:[NSNumber numberWithInteger:kNASTifySettingExternalPlayerTypeVlc]
                                     forKey:kNASTifySettingExternalPlayerType];
                    }
                    break;
                }
                case 1: // AcePlayer
                {
                    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"aceplayer://"]])
                    {
                        [defaults setObject:[NSNumber numberWithInteger:kNASTifySettingExternalPlayerTypeAceplayer]
                                     forKey:kNASTifySettingExternalPlayerType];
                    }
                    break;
                }
                case 2: // GPlayer
                {
                    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"gplayer://"]])
                    {
                        [defaults setObject:[NSNumber numberWithInteger:kNASTifySettingExternalPlayerTypeGplayer]
                                     forKey:kNASTifySettingExternalPlayerType];
                    }
                    break;
                }
                case 3: // OPlayer
                {
                    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"oplayer://"]])
                    {
                        [defaults setObject:[NSNumber numberWithInteger:kNASTifySettingExternalPlayerTypeOplayer]
                                     forKey:kNASTifySettingExternalPlayerType];
                    }
                    break;
                }
                case 4: // GoodPlayer
                {
                    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"goodplayer://"]])
                    {
                        [defaults setObject:[NSNumber numberWithInteger:kNASTifySettingExternalPlayerTypeGoodplayer]
                                     forKey:kNASTifySettingExternalPlayerType];
                    }
                    break;
                }
            }
            [self.tableView reloadData];
            break;
        }
        case SETTINGS_PASSCODE_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    if ([LTHPasscodeViewController doesPasscodeExist])
                    {
                        [[LTHPasscodeViewController sharedUser] showForDisablingPasscodeInViewController:self.navigationController asModal:YES];
                    }
                    else
                    {
                        [[LTHPasscodeViewController sharedUser] showForEnablingPasscodeInViewController:self.navigationController asModal:YES];
                    }
                    break;
                }
                case 1:
                {
                    if ([LTHPasscodeViewController doesPasscodeExist])
                    {
                        [[LTHPasscodeViewController sharedUser] showForChangingPasscodeInViewController:self.navigationController asModal:YES];
                    }
                    break;
                }
                case 2:
                {
                    TableSelectViewController *tableSelectViewController;
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStylePlain];
                    }
                    else
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStyleGrouped];
                    }
                    tableSelectViewController.elements = self.delayOptions;
                    tableSelectViewController.selectedElement = self.delayIndex;
                    tableSelectViewController.delegate = self;
                    tableSelectViewController.tag = TAG_CODEDELAY;
                    
                    [self.navigationController pushViewController:tableSelectViewController animated:YES];
                    break;
                }
            }
            break;
        }
        case SETTINGS_GCAST_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 1:
                {
                    // Configure the cell...
                    if (self.gcController.isConnected)
                    {
                        // End connection with device
                        [self.gcController disconnectFromDevice];
                    }
                    else
                    {
                        // Show list
                        //Choose device
                        UIActionSheet *gcActionSheet =
                        [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Connect to Device", nil)
                                                    delegate:self
                                           cancelButtonTitle:nil
                                      destructiveButtonTitle:nil
                                           otherButtonTitles:nil];
                        
                        for (GCKDevice *device in self.gcController.deviceScanner.devices)
                        {
                            [gcActionSheet addButtonWithTitle:device.friendlyName];
                        }
                        
                        [gcActionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
                        gcActionSheet.cancelButtonIndex = self.gcActionSheet.numberOfButtons - 1;
                        
                        //show device selection
                        [gcActionSheet showInView:self.view];

                    }

                    break;
                }
            }
            break;
        }
        case SETTINGS_ABOUT_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    AboutViewController *viewController = [[AboutViewController alloc] init];
                    [self.navigationController pushViewController:viewController animated:YES];
                    break;
                }
                case 1:
                {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://forum.codeisalie.com/viewforum.php?f=8"]];
                    break;
                }
                case 2:
                {
                    NSArray *objectsToShare = [NSArray arrayWithObject:NSLocalizedString(@"Hey,\ryou should really have a look at this great file management app/media player for iPhone/iPad : http://nastify.codeisalie.com", nil)];
                    
                    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:objectsToShare
                                                                                                         applicationActivities:nil];
                    
                    NSArray *excludeActivities = [NSArray arrayWithObjects:
                                                  UIActivityTypePrint,
                                                  UIActivityTypeAssignToContact,
                                                  UIActivityTypeSaveToCameraRoll,
                                                  UIActivityTypeAddToReadingList,
                                                  UIActivityTypePostToFlickr,
                                                  UIActivityTypePostToVimeo,
                                                  nil];
                    
                    activityViewController.excludedActivityTypes = excludeActivities;
                    
                    if ([activityViewController respondsToSelector:@selector(popoverPresentationController)])
                    {
                        activityViewController.popoverPresentationController.sourceView = self.view;
                        activityViewController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
                        activityViewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;
                    }
                    
                    [self presentViewController:activityViewController
                                       animated:YES
                                     completion:nil];
                    break;
                }
            }
            break;
        }
        case SETTINGS_PURCHASE_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    // Start the network activity spinner
                    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

                    [[MKStoreKit sharedKit] restorePurchases];
                    break;
                }
                case 2:
                {
                    PurchaseServerViewController *viewController = [[PurchaseServerViewController alloc] initWithStyle:UITableViewStyleGrouped];
                    [self.navigationController pushViewController:viewController animated:YES];

                    break;
                }
            }
            break;
        }
#endif
        default:
            break;
    }
}

- (void)segmentedValueChanged:(id)sender {
	NSInteger tag = ((UISegmentedControl *)sender).tag;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
	switch (tag)
    {
		case TAG_MEDIA_PLAYER_TYPE:
        {
            [defaults setObject:[NSNumber numberWithLong:(long)[sender selectedSegmentIndex]]
                         forKey:kNASTifySettingPlayerType];
            break;
        }
		case TAG_MEDIA_PLAYER:
        {
            [defaults setObject:[NSNumber numberWithLong:(long)[sender selectedSegmentIndex]]
                         forKey:kNASTifySettingInternalPlayer];
            break;
        }
	}
    [defaults synchronize];
    [self.tableView reloadData];
}

#if TARGET_OS_IOS
- (void)switchValueChanged:(id)sender
{
	NSInteger tag = ((UISwitch *)sender).tag;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
	switch (tag)
    {
		case TAG_SIMPLECODE:
        {
            [[LTHPasscodeViewController sharedUser] setIsSimple:[sender isOn] inViewController:self.navigationController asModal:YES];
			break;
        }
        case TAG_TOUCHID:
        {
            [[LTHPasscodeViewController sharedUser] setAllowUnlockWithTouchID:[sender isOn]];
            break;
        }
        case TAG_BROWSER_GCAST:
        {
            [defaults setObject:[NSNumber numberWithBool:[sender isOn]]
                         forKey:kNASTifySettingBrowserShowGCast];
            break;
        }
	}
    [defaults synchronize];
    [self.tableView reloadData];
}
#endif

#if TARGET_OS_IOS
- (void)selectedElementIndex:(NSInteger)elementIndex forTag:(NSInteger)tag
{
	switch (tag)
    {
        case TAG_CODEDELAY:
        {
            [LTHPasscodeViewController saveTimerDuration:[[self.delayValues objectAtIndex:elementIndex] doubleValue]];
            self.delayIndex = elementIndex;
            [self.tableView reloadData];
            break;
        }
    }
    [self.tableView reloadData];
}
#endif

#pragma mark - GoogleCast support

#if TARGET_OS_IOS
- (void)updateGCState
{
    [self.tableView reloadData];
}

- (void)didDiscoverDeviceOnNetwork
{
    [self.tableView reloadData];
}

- (void)didReceiveMediaStateChange
{
}

- (void)didConnectToDevice:(GCKDevice *)device
{
    [self.tableView reloadData];
}
#endif

#pragma mark - UIActionSheetDelegate

#if TARGET_OS_IOS
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (self.gcController.selectedDevice == nil)
    {
        if (buttonIndex < self.gcController.deviceScanner.devices.count)
        {
            _gcController.selectedDevice = _gcController.deviceScanner.devices[buttonIndex];
            NSLog(@"Selecting device:%@", _gcController.selectedDevice.friendlyName);
            [_gcController connectToDevice];
        }
    }
}
#endif

#pragma mark - MAConfirmButton action button

#if TARGET_OS_IOS
- (void)confirmAction:(id)sender
{
    MAConfirmButton *button = (MAConfirmButton *)sender;
    [button disableWithTitle:NSLocalizedString(@"Processing", nil)];
    
    SKProduct *product = [[MKStoreKit sharedKit].availableProducts objectAtIndex:button.tag];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

    [[MKStoreKit sharedKit] initiatePaymentRequestForProductWithIdentifier:product.productIdentifier];
}
#endif

#pragma mark - TableSelectViewController Delegate

#if TARGET_OS_TV
- (void)selectedElementIndex:(NSInteger)elementIndex forTag:(NSInteger)tag
{
    switch (tag)
    {
        case TAG_SORTING_TYPE:
        {
            self.selectedSortingOptionIndex = elementIndex;
            [self saveSorting];
            [self.tableView reloadData];
            break;
        }
        default:
        {
            break;
        }
    }
}
#endif

#pragma mark - Sorting method saving
#if TARGET_OS_TV
- (void)saveSorting
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    FileItemSortType selectedSorting;
    switch (self.selectedSortingOptionIndex)
    {
            case 0: // name
        {
            if (self.foldersFirst)
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_NAME_DESC_FOLDER_FIRST;
                }
                else
                {
                    selectedSorting = SORT_BY_NAME_ASC_FOLDER_FIRST;
                }
            }
            else
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_NAME_DESC;
                }
                else
                {
                    selectedSorting = SORT_BY_NAME_ASC;
                }
            }
            break;
        }
            case 1: // date
        {
            if (self.foldersFirst)
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_DATE_DESC_FOLDER_FIRST;
                }
                else
                {
                    selectedSorting = SORT_BY_DATE_ASC_FOLDER_FIRST;
                }
            }
            else
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_DATE_DESC;
                }
                else
                {
                    selectedSorting = SORT_BY_DATE_ASC;
                }
            }
            break;
        }
            case 2: // type
        {
            if (self.foldersFirst)
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_TYPE_DESC_FOLDER_FIRST;
                }
                else
                {
                    selectedSorting = SORT_BY_TYPE_ASC_FOLDER_FIRST;
                }
            }
            else
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_TYPE_DESC;
                }
                else
                {
                    selectedSorting = SORT_BY_TYPE_ASC;
                }
            }
            break;
        }
            case 3: // size
        {
            if (self.foldersFirst)
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_SIZE_DESC_FOLDER_FIRST;
                }
                else
                {
                    selectedSorting = SORT_BY_SIZE_ASC_FOLDER_FIRST;
                }
            }
            else
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_SIZE_DESC;
                }
                else
                {
                    selectedSorting = SORT_BY_SIZE_ASC;
                }
            }
            break;
        }
        default:
            break;
    }
    [defaults setInteger:selectedSorting forKey:@"sortingType"];
}
#endif

#pragma mark - Memory management

- (void)dealloc
{
#if TARGET_OS_IOS
    if (self.gcController.delegate == self)
    {
        self.gcController.delegate = nil;
    }
#endif
}

@end
