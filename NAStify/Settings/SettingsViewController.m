//
//  SettingsViewController.m
//  NAStify
//
//  Created by Sylver Bruneau on 16/04/2014.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "SettingsViewController.h"
#import "SegCtrlCell.h"
#import "SwitchCell.h"
#import "TextCell.h"
#import "SDImageCache.h"
#import "LTHPasscodeViewController.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "AboutViewController.h"
#import "SKProduct+priceAsString.h"
#import "MAConfirmButton.h"
#import "SBNetworkActivityIndicator.h"
#import "PurchaseServerViewController.h"

#define SETTINGS_PURCHASE_SECTION_INDEX 0
#define SETTINGS_ABOUT_SECTION_INDEX 1
#define SETTINGS_FILEBROWSER_SECTION_INDEX 2
#define SETTINGS_MEDIA_PLAYER_TYPE_SECTION_INDEX 3
#define SETTINGS_MEDIA_PLAYER_INTERNAL_SECTION_INDEX 4
#define SETTINGS_MEDIA_PLAYER_EXTERNAL_SECTION_INDEX 5
#define SETTINGS_PASSCODE_SECTION_INDEX 6
#define SETTINGS_GCAST_SECTION_INDEX 7

#define TAG_BROWSER_GCAST       0
#define TAG_MEDIA_PLAYER        1
#define TAG_MEDIA_PLAYER_TYPE   2
#define TAG_SIMPLECODE          3
#define TAG_CODEDELAY           4
#define TAG_TOUCHID             5

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
    NSInteger index;
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Settings", nil);
    
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
    self.gcController.delegate = self;
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
            numberOfRows = 1;
            break;
        }
        case SETTINGS_MEDIA_PLAYER_TYPE_SECTION_INDEX:
        {
            numberOfRows = 1;
            break;
        }
        case SETTINGS_MEDIA_PLAYER_INTERNAL_SECTION_INDEX:
        {
            if ([[defaults objectForKey:kNASTifySettingPlayerType] integerValue] == kNASTifySettingPlayerTypeInternal)
            {
                numberOfRows = 2;
            }
            break;
        }
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
        case SETTINGS_MEDIA_PLAYER_TYPE_SECTION_INDEX:
        {
            title = NSLocalizedString(@"Media player Selection",nil);
            break;
        }
        case SETTINGS_MEDIA_PLAYER_INTERNAL_SECTION_INDEX:
        {
            if ([[defaults objectForKey:kNASTifySettingPlayerType] integerValue] == kNASTifySettingPlayerTypeInternal)
            {
                title = NSLocalizedString(@"Internal media player",nil);
            }
            break;
        }
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
            if (self.gcController.deviceScanner.devices.count > 0)
            {
                title = NSLocalizedString(@"Google Cast",nil);
            }
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
    }
    return title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
	static NSString *TextCellIdentifier = @"TextCell";
	static NSString *SwitchCellIdentifier = @"SwitchCell";
    static NSString *SegmentedControllerCell1Identifier = @"SegmentedControllerCell1";
    static NSString *SegmentedControllerCell2Identifier = @"SegmentedControllerCell2";
    static NSString *PurchaseCellIdentifier = @"PurchaseCell";
    UITableViewCell *cell = nil;
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];

    switch (indexPath.section)
    {
        case SETTINGS_FILEBROWSER_SECTION_INDEX:
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
                    
                    // Configure the cell...
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.textColor = [UIColor blackColor];
                    cell.textLabel.text = [NSString stringWithFormat:@"Clear Photo Cache (%ld MB)",(long)([[SDImageCache sharedImageCache] getSize]/(1024*1024))];
                    
                    break;
                }
                default:
                {
                    break;
                }
            }
            break;
        }
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
        case SETTINGS_MEDIA_PLAYER_INTERNAL_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
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
        default:
        {
            break;
        }
    }
    return cell;
}

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
                case 0:
                {
                    [[SDImageCache sharedImageCache] clearDisk];
                    [[SDImageCache sharedImageCache] clearMemory];
                    [self.tableView reloadData];
                    break;
                }
            }
            break;
        }
        case SETTINGS_MEDIA_PLAYER_INTERNAL_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
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

#pragma mark - GoogleCast support

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

#pragma mark - UIActionSheetDelegate

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

#pragma mark - MAConfirmButton action button

- (void)confirmAction:(id)sender
{
    MAConfirmButton *button = (MAConfirmButton *)sender;
    [button disableWithTitle:NSLocalizedString(@"Processing", nil)];
    
    SKProduct *product = [[MKStoreKit sharedKit].availableProducts objectAtIndex:button.tag];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

    [[MKStoreKit sharedKit] initiatePaymentRequestForProductWithIdentifier:product.productIdentifier];
}

#pragma mark - Memory management

- (void)dealloc
{
    if (self.gcController.delegate == self)
    {
        self.gcController.delegate = nil;
    }
}

@end
