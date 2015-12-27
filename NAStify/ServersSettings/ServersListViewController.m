//
//  ServersListViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServersListViewController.h"
#import "ServerSettingsWebDavViewController.h"
#import "ServerSettingsFreeboxRevViewController.h"
#import "ServerSettingsFtpViewController.h"
#import "ServerSettingsBoxViewController.h"
#import "ServerSettingsGoogleDriveViewController.h"
#import "ServerSettingsDropboxViewController.h"
#import "ServerSettingsMegaViewController.h"
#import "ServerSettingsOneDriveViewController.h"
#import "ServerSettingsOwnCloudViewController.h"
#import "ServerSettingsQnapViewController.h"
#import "ServerSettingsSambaViewController.h"
#import "ServerSettingsSynologyViewController.h"
#import "UserAccount.h"
#import "AppDelegate.h"
#import "FileBrowserViewController.h"
#import "ServerTypeViewController.h"
#import "ServerCell.h"
#import "SSKeychain.h"

@interface ServersListViewController (PrivateMethods)
- (void)addButtonPressed;
- (void)save;
- (void)handleEnteredBackground:(NSNotification *)notification;
- (void)handleBecomeActive:(NSNotification *)notification;
// UPnP
- (void)startUPNPDiscovery;
- (void)stopUPNPDiscovery;
- (void)performSSDPSearch;
@end

@implementation ServersListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // TableView settings
    self.tableView.allowsSelectionDuringEditing = YES;

    self.smbDevices = [[NSMutableArray alloc] init];

    // Navigation settings
    self.navigationItem.title = NSLocalizedString(@"Server list",nil);
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addButtonPressed)];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    NSData * accountsData = [defaults objectForKey:@"accounts"];
    if (!accountsData)
    {
        self.accounts = [[NSMutableArray alloc] init];
    }
    else
    {
        self.accounts = [[NSMutableArray alloc] initWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:accountsData]];
    }
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    
    // Reachability
    self.manager = [AFHTTPRequestOperationManager manager];
    
    __weak __typeof(self)weakSelf = self;
    __weak __typeof(_filteredUPNPDevices)weakFilteredUPNPDevices = _filteredUPNPDevices;
    __weak __typeof(self.smbDevices)weakSmbDevices = self.smbDevices;

    [self.manager.reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        __strong __typeof(weakFilteredUPNPDevices)strongFilteredUPNPDevices = weakFilteredUPNPDevices;
        switch (status) {
            case AFNetworkReachabilityStatusReachableViaWiFi:
                [weakSelf performSelectorInBackground:@selector(startUPNPDiscovery) withObject:nil];
                [weakSelf performSelectorInBackground:@selector(startNetbiosDiscovery) withObject:nil];
                break;
            default:
                [weakSelf stopUPNPDiscovery];
                strongFilteredUPNPDevices = nil;
                [weakSelf stopNetbiosDiscovery];
                [weakSmbDevices removeAllObjects];
                [weakSelf.tableView reloadData];
                break;
        }
    }];
    [self.manager.reachabilityManager startMonitoring];

    // Register account changes notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(addAccountNotification:)
                                                 name:@"ADDACCOUNT"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateAccountNotification:)
                                                 name:@"UPDATEACCOUNT"
                                               object:nil];
    
    // Register to application notifications
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleEnteredBackground:)
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleBecomeActive:)
                                                 name: UIApplicationDidBecomeActiveNotification
                                               object: nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopUPNPDiscovery];
    [self stopNetbiosDiscovery];
}

- (void)handleEnteredBackground:(NSNotification *)notification
{
    [self stopUPNPDiscovery];
    [self stopNetbiosDiscovery];
}

- (void)handleBecomeActive:(NSNotification *)notification
{
    if (self.manager.reachabilityManager.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi)
    {
        [self performSelectorInBackground:@selector(startUPNPDiscovery) withObject:nil];
        [self performSelectorInBackground:@selector(startNetbiosDiscovery) withObject:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    // Hide toolbar
    [self.navigationController setToolbarHidden:YES animated:NO];

    if (self.manager.reachabilityManager.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi)
    {
        [self performSelectorInBackground:@selector(startUPNPDiscovery) withObject:nil];
        [self performSelectorInBackground:@selector(startNetbiosDiscovery) withObject:nil];
    }

    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - Table view methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 51.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL result = NO;
    switch (indexPath.section)
    {
        case 0:
        {
            result = NO;
            break;
        }
        default:
            break;
    }
    return result;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger rows = 0;
    switch (section)
    {
        case 0: // Servers
        {
            rows = [self.accounts count];
            break;
        }
        case 1: // UPnP
        {
            if (self.manager.reachabilityManager.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi)
            {
                rows = _filteredUPNPDevices.count;
            }
            break;
        }
        case 2: // SMB/CIFS
        {
            if (self.smbDevices.count > 0)
            {
                rows = self.smbDevices.count;
            }
            break;
        }
        default:
        {
            break;
        }
    }
    return rows;
}

- (NSString *)tableView:(UITableView *)atableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionName = nil;
    switch (section)
    {
        case 0:
        {
            sectionName = NSLocalizedString(@"Servers",nil);
            break;
        }
        case 1:
        {
            if ((self.manager.reachabilityManager.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi) &&
                (_filteredUPNPDevices.count > 0))
            {
                sectionName = NSLocalizedString(@"UPnP",nil);
            }
            break;
        }
        case 2:
        {
            if (self.manager.reachabilityManager.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi)
            {
                sectionName = NSLocalizedString(@"Windows Shares (SMB/CIFS)",nil);
            }
            break;
        }
        default:
        {
            break;
        }
    }
    return sectionName;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * ServerCellIdentifier = @"ServerCell";
    static NSString * UPnPCellIdentifier = @"UPnPCell";
    UITableViewCell *cell = nil;
    
    switch (indexPath.section)
    {
        case 0:
        {
            ServerCell *serverCell = (ServerCell *)[tableView dequeueReusableCellWithIdentifier:ServerCellIdentifier];
            if (serverCell == nil)
            {
                serverCell = [[ServerCell alloc] initWithStyle:UITableViewCellStyleDefault
                                               reuseIdentifier:ServerCellIdentifier];
            }
            
            // Configure the cell...
            serverCell.editingAccessoryType = UITableViewCellAccessoryDisclosureIndicator;
            serverCell.showsReorderControl = YES;
            [serverCell setAccount:[self.accounts objectAtIndex:indexPath.row]];
            cell = serverCell;
            break;
        }
        case 1: // UPnP
        {
            ServerCell *serverCell = [tableView dequeueReusableCellWithIdentifier:UPnPCellIdentifier];
            if (serverCell == nil)
            {
                serverCell = [[ServerCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                    reuseIdentifier:UPnPCellIdentifier];
            }
            // Get device info
            BasicUPnPDevice *device = _filteredUPNPDevices[indexPath.row];

            serverCell.textLabel.text = [device friendlyName];
            if ([device smallIcon])
            {
                [serverCell serverImage:[device smallIcon]];
            }
            else
            {
                serverCell.imageView.image = [UIImage imageNamed:@"upnp_small.png"];
            }
            
            serverCell.editingAccessoryType = UITableViewCellAccessoryNone;
            serverCell.showsReorderControl = NO;
            cell = serverCell;
            break;
        }
        case 2: // SMB/CIFS
        {
            ServerCell *serverCell = (ServerCell *)[tableView dequeueReusableCellWithIdentifier:ServerCellIdentifier];
            if (serverCell == nil)
            {
                serverCell = [[ServerCell alloc] initWithStyle:UITableViewCellStyleDefault
                                               reuseIdentifier:ServerCellIdentifier];
            }
            
            // Configure the cell...
            serverCell.editingAccessoryType = UITableViewCellAccessoryNone;
            serverCell.showsReorderControl = NO;
            
            UserAccount *account = [[UserAccount alloc] init];
            account.serverType = SERVER_TYPE_SAMBA;
            account.accountName = [NSString stringWithFormat:@"%@ (IP : %@)",[[self.smbDevices objectAtIndex:indexPath.row] objectForKey:@"hostname"],[[self.smbDevices objectAtIndex:indexPath.row] objectForKey:@"ip"]];
            [serverCell setAccount:account];
            cell = serverCell;
            break;
        }
        default:
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.editing)
    {
        switch (indexPath.section)
        {
            case 0: // Servers
            {
                // Edit account
                UserAccount *account = [self.accounts objectAtIndex:indexPath.row];
                switch (account.serverType)
                {
                    case SERVER_TYPE_WEBDAV:
                    {
                        ServerSettingsWebDavViewController *svc = [[ServerSettingsWebDavViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                                 andAccount:account
                                                                                                                   andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_FTP:
                    case SERVER_TYPE_SFTP:
                    {
                        ServerSettingsFtpViewController *svc = [[ServerSettingsFtpViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                           andAccount:account
                                                                                                             andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_SYNOLOGY:
                    {
                        ServerSettingsSynologyViewController *svc = [[ServerSettingsSynologyViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                                     andAccount:account
                                                                                                                       andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_PYDIO:
                    {
                        ServerSettingsQnapViewController *svc = [[ServerSettingsQnapViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                             andAccount:account
                                                                                                               andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_QNAP:
                    {
                        ServerSettingsQnapViewController *svc = [[ServerSettingsQnapViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                             andAccount:account
                                                                                                               andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_FREEBOX_REVOLUTION:
                    {
                        ServerSettingsFreeboxRevViewController *svc = [[ServerSettingsFreeboxRevViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                                         andAccount:account
                                                                                                                           andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_SAMBA:
                    {
                        ServerSettingsSambaViewController *svc = [[ServerSettingsSambaViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                                         andAccount:account
                                                                                                                           andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_DROPBOX:
                    {
                        ServerSettingsDropboxViewController *svc = [[ServerSettingsDropboxViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                                   andAccount:account
                                                                                                                     andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_BOX:
                    {
                        ServerSettingsBoxViewController *svc = [[ServerSettingsBoxViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                           andAccount:account
                                                                                                             andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_GOOGLEDRIVE:
                    {
                        ServerSettingsGoogleDriveViewController *svc =
                        [[ServerSettingsGoogleDriveViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                            andAccount:account
                                                                              andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_MEGA:
                    {
                        ServerSettingsMegaViewController *svc = [[ServerSettingsMegaViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                             andAccount:account
                                                                                                               andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_ONEDRIVE:
                    {
                        ServerSettingsOneDriveViewController *svc = [[ServerSettingsOneDriveViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                                     andAccount:account
                                                                                                                       andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_OWNCLOUD:
                    {
                        ServerSettingsOwnCloudViewController *svc = [[ServerSettingsOwnCloudViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                                     andAccount:account
                                                                                                                       andIndex:indexPath.row];
                        svc.userAccount = [self.accounts objectAtIndex:indexPath.row];
                        [self.navigationController pushViewController:svc animated:YES];
                        break;
                    }
                    case SERVER_TYPE_UNKNOWN:
                    case SERVER_TYPE_LOCAL:
                    case SERVER_TYPE_UPNP:
                    {
                        // Nothing to do
                        break;
                    }
                }
                break;
            }
        }
    }
    else
    {
        switch (indexPath.section)
        {
            case 0: // Servers
            {
                [self save];
                
                FileItem *rootFolder = [[FileItem alloc] init];
                rootFolder.isDir = YES;
                rootFolder.path = @"/";
                rootFolder.objectIds = [NSArray arrayWithObject:kRootID];

                FileBrowserViewController *fileBrowserViewController = [[FileBrowserViewController alloc] init];
                fileBrowserViewController.userAccount = [self.accounts objectAtIndex:indexPath.row];
                fileBrowserViewController.currentFolder = rootFolder;
                
                [self.navigationController pushViewController:fileBrowserViewController animated:YES];
                break;
            }
            case 1: // UPnP
            {
                BasicUPnPDevice *device = _filteredUPNPDevices[indexPath.row];
                if ([[device urn] isEqualToString:@"urn:schemas-upnp-org:device:MediaServer:1"])
                {
                    MediaServer1Device *server = (MediaServer1Device*)device;
                    
                    UserAccount *account = [[UserAccount alloc] init];
                    account.serverType = SERVER_TYPE_UPNP;
                    account.serverObject = server;
                    
                    FileItem *rootFolder = [[FileItem alloc] init];
                    rootFolder.isDir = YES;
                    rootFolder.path = @"/";
                    rootFolder.objectIds = [NSArray arrayWithObject:@"0"];

                    FileBrowserViewController *fileBrowserViewController = [[FileBrowserViewController alloc] init];
                    fileBrowserViewController.userAccount = account;
                    fileBrowserViewController.currentFolder = rootFolder;
                    
                    [self.navigationController pushViewController:fileBrowserViewController animated:YES];
                }
                break;
            }
            case 2: // SMB/CIFS
            {
                UserAccount *account = [[UserAccount alloc] init];
                account.accountName = [[self.smbDevices objectAtIndex:indexPath.row] objectForKey:@"hostname"];
                account.serverType = SERVER_TYPE_SAMBA;
                account.server = [[self.smbDevices objectAtIndex:indexPath.row] objectForKey:@"hostname"];
                account.serverObject = [[self.smbDevices objectAtIndex:indexPath.row] objectForKey:@"group"];
                
                FileItem *rootFolder = [[FileItem alloc] init];
                rootFolder.isDir = YES;
                rootFolder.path = @"/";
                rootFolder.objectIds = [NSArray arrayWithObject:kRootID];
                
                FileBrowserViewController *fileBrowserViewController = [[FileBrowserViewController alloc] init];
                fileBrowserViewController.userAccount = account;
                fileBrowserViewController.currentFolder = rootFolder;
                
                [self.navigationController pushViewController:fileBrowserViewController animated:YES];
                break;
            }
            default:
                break;
        }
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (UITableViewCellEditingStyle)tableView:(UITableView*)tableView editingStyleForRowAtIndexPath:(NSIndexPath*)indexPath
{
    if (self.editing && indexPath.section == 0)
    {
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        if (indexPath.section == 0)
        {
            UserAccount *account = [self.accounts objectAtIndex:indexPath.row];
            switch (account.serverType) {
                case SERVER_TYPE_DROPBOX:
                {
                    if (account.userName != nil)
                    {
                        // unlink account if it's a dropbox account
                        [[DBSession sharedSession] unlinkUserId:account.userName];
                    }
                    break;
                }
                    
                default:
                    break;
            }
            // delete entries in keychain
            switch (account.serverType)
            {
                case SERVER_TYPE_GOOGLEDRIVE:
                {
                    [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:account.uuid];
                    break;
                }
                default:
                {
                    [SSKeychain deletePasswordForService:account.uuid
                                                 account:@"password"];
                    [SSKeychain deletePasswordForService:account.uuid
                                                 account:@"token"];
                    [SSKeychain deletePasswordForService:account.uuid
                                                 account:@"pubCert"];
                    [SSKeychain deletePasswordForService:account.uuid
                                                 account:@"privCert"];
                    break;
                }
            }
            
            [self.accounts removeObjectAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
            [self save];
            // Update
            [self.tableView reloadData];
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL canMove = NO;
    if (indexPath.section == 0)
    {
        if ([self.accounts count] > 1)
        {
            canMove = YES;
        }
    }
    return canMove;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    if ((sourceIndexPath.section == 0) && (destinationIndexPath.section == 0))
    {
        UserAccount *accountToMove = [self.accounts objectAtIndex:sourceIndexPath.row];
        [self.accounts removeObjectAtIndex:sourceIndexPath.row];
        [self.accounts insertObject:accountToMove atIndex:destinationIndexPath.row];
        [self save];
    }
    else
    {
        [self.tableView reloadData];
    }
}

#pragma mark - TextFieldDelegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}


#pragma mark - Notification Methods

- (void)addAccountNotification:(NSNotification*)notification
{
    if ([notification userInfo] == nil) return;
    
    if ([[notification userInfo] objectForKey:@"account"])
    {
        // Save new server
        [self.accounts addObject:[[notification userInfo] objectForKey:@"account"]];
        [self save];
        [self.tableView reloadData];
    }
}

- (void)updateAccountNotification:(NSNotification*)notification
{
    if ([notification userInfo] == nil) return;
    
    if (([[notification userInfo] objectForKey:@"account"]) && ([[notification userInfo] objectForKey:@"accountIndex"]))
    {
        // Update server
        NSInteger index = [[[notification userInfo] objectForKey:@"accountIndex"] intValue];
        [self.accounts removeObjectAtIndex:index];
        [self.accounts insertObject:[[notification userInfo] objectForKey:@"account"] atIndex:index];
        [self save];
        [self.tableView reloadData];
    }
    else if ([[notification userInfo] objectForKey:@"account"])
    {
        // Check that the account is existing in the context
        BOOL indexFound = NO;
        for (UserAccount *account in self.accounts)
        {
            if (account == [[notification userInfo] objectForKey:@"account"])
            {
                indexFound = YES;
                break;
            }
        }

        // Save updated information
        if (indexFound)
        {
            [self save];
            [self.tableView reloadData];
        }
    }
}

#pragma mark - uPnP support

- (void)startUPNPDiscovery
{
    if ((self.manager.reachabilityManager.networkReachabilityStatus != AFNetworkReachabilityStatusReachableViaWiFi) ||
        _udnpDiscoveryRunning)
    {
        return;
    }
    
    UPnPManager *managerInstance = [UPnPManager GetInstance];
    
    _UPNPdevices = [[managerInstance DB] rootDevices];
    
    if (_UPNPdevices.count > 0)
    {
        [self UPnPDBUpdated:nil];
    }
    
    [[managerInstance DB] addObserver:self];
    
    //Optional; set User Agent
    [[managerInstance SSDP] setUserAgentProduct:[NSString stringWithFormat:@"NAStify/%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]] andOS:[NSString stringWithFormat:@"iOS/%@", [[UIDevice currentDevice] systemVersion]]];
    
    //Search for UPnP Devices
    [[managerInstance SSDP] startSSDP];
    [[managerInstance SSDP] notifySSDPAlive];
    _searchTimer = [NSTimer timerWithTimeInterval:10.0 target:self selector:@selector(performSSDPSearch) userInfo:nil repeats:YES];
    [_searchTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [[NSRunLoop mainRunLoop] addTimer:_searchTimer forMode:NSRunLoopCommonModes];
    _udnpDiscoveryRunning = YES;
}

- (void)stopUPNPDiscovery
{
    if (_udnpDiscoveryRunning) {
        UPnPManager *managerInstance = [UPnPManager GetInstance];
        [[managerInstance SSDP] notifySSDPByeBye];
        [_searchTimer invalidate];
        _searchTimer = nil;
        [[managerInstance DB] removeObserver:self];
        [[managerInstance SSDP] stopSSDP];
        _udnpDiscoveryRunning = NO;
    }
}

- (void)performSSDPSearch
{
    UPnPManager *managerInstance = [UPnPManager GetInstance];
    [[managerInstance SSDP] searchSSDP];
    [[managerInstance SSDP] searchForMediaServer];
    [[managerInstance SSDP] SSDPDBUpdate];
}

//protocol UPnPDBObserver
- (void)UPnPDBWillUpdate:(UPnPDB*)sender
{
}

- (void)UPnPDBUpdated:(UPnPDB*)sender
{
    NSUInteger count = _UPNPdevices.count;
    BasicUPnPDevice *device;
    NSMutableArray *mutArray = [[NSMutableArray alloc] init];
    for (NSUInteger x = 0; x < count; x++) {
        device = _UPNPdevices[x];
        if ([[device urn] isEqualToString:@"urn:schemas-upnp-org:device:MediaServer:1"])
        {
            [mutArray addObject:device];
        }
    }
    _filteredUPNPDevices = nil;
    _filteredUPNPDevices = [NSArray arrayWithArray:mutArray];
    
    [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

#pragma mark - SMB/CIFS

static void on_entry_added(void *p_opaque,
                           netbios_ns_entry *entry)
{
    struct in_addr addr;
    BOOL addServer = YES;
    addr.s_addr = netbios_ns_entry_ip(entry);
    
    ServersListViewController *c_self = (__bridge ServersListViewController *)(p_opaque);
    NSMutableArray *array = c_self.smbDevices;
    
    NSString *ipString = [NSString stringWithFormat:@"%s",inet_ntoa(addr)];
    NSString *hostname = [NSString stringWithFormat:@"%s",netbios_ns_entry_name(entry)];
    NSString *group = [NSString stringWithFormat:@"%s",netbios_ns_entry_group(entry)];
    
    NSMutableArray *entriesToAdd = [[NSMutableArray alloc] init];
    
    // Check if server is not already present before adding it
    for (NSDictionary *server in array)
    {
        if (([[server objectForKey:@"ip"] isEqualToString:ipString]) &&
            ([[server objectForKey:@"hostname"] isEqualToString:hostname]) &&
            ([[server objectForKey:@"group"] isEqualToString:group]))
        {
            addServer = NO;
        }
    }
    if (addServer)
    {
        NSDictionary *serverDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    ipString, @"ip",
                                    hostname, @"hostname",
                                    group, @"group",
                                    nil];
        
        [entriesToAdd addObject:serverDict];
    }
    
    if (entriesToAdd.count > 0)
    {
        [array addObjectsFromArray:entriesToAdd];
        dispatch_async(dispatch_get_main_queue(), ^{
            [c_self.tableView reloadData];
        });
    }
    NSLog(@"on_entry_added %@", entriesToAdd);
}

static void on_entry_removed(void *p_opaque,
                             netbios_ns_entry *entry)
{
    struct in_addr addr;
    addr.s_addr = netbios_ns_entry_ip(entry);
    
    ServersListViewController *c_self = (__bridge ServersListViewController *)(p_opaque);
    NSMutableArray *array = c_self.smbDevices;
    
    NSString *ipString = [NSString stringWithFormat:@"%s",inet_ntoa(addr)];
    NSString *hostname = [NSString stringWithFormat:@"%s",netbios_ns_entry_name(entry)];
    NSString *group = [NSString stringWithFormat:@"%s",netbios_ns_entry_group(entry)];
    
    NSMutableArray *entriesToRemove = [[NSMutableArray alloc] init];
    for (NSDictionary *server in array)
    {
        if (([[server objectForKey:@"ip"] isEqualToString:ipString]) &&
            ([[server objectForKey:@"hostname"] isEqualToString:hostname]) &&
            ([[server objectForKey:@"group"] isEqualToString:group]))
        {
            // Add this server to list to remove
            [entriesToRemove addObject:server];
            
        }
    }
    if (entriesToRemove.count > 0)
    {
        [array removeObjectsInArray:entriesToRemove];
        dispatch_async(dispatch_get_main_queue(), ^{
            [c_self.tableView reloadData];
        });
    }
    NSLog(@"on_entry_removed %@", entriesToRemove);
}

- (void)startNetbiosDiscovery
{
    netbios_ns_discover_callbacks callbacks;
    
    if ((self.manager.reachabilityManager.networkReachabilityStatus != AFNetworkReachabilityStatusReachableViaWiFi) ||
        _netbiosDiscoveryRunning)
    {
        return;
    }
    
    [self.smbDevices removeAllObjects];
    _ns = netbios_ns_new();
    
    callbacks.p_opaque = (__bridge void *)self;
    callbacks.pf_on_entry_added = on_entry_added;
    callbacks.pf_on_entry_removed = on_entry_removed;
    
    NSLog(@"Discovering SMB/CIFS ...");
    if (!netbios_ns_discover_start(_ns,
                                   4, // broadcast every 4 sec
                                   &callbacks))
    {
        NSLog(@"Error while discovering local network\n");
    }
    _netbiosDiscoveryRunning = YES;
}

- (void)stopNetbiosDiscovery
{
    if (_netbiosDiscoveryRunning)
    {
        netbios_ns_discover_stop(_ns);
        _netbiosDiscoveryRunning = NO;
    }
}

#pragma mark - Private Methods implementation

- (void)addButtonPressed {
    // New server creation
    ServerTypeViewController * stc = [[ServerTypeViewController alloc] initWithStyle:UITableViewStyleGrouped];
    [self.navigationController pushViewController:stc animated:YES];
    [self.tableView reloadData];
}

- (void)save
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:self.accounts] forKey:@"accounts"];
    [defaults synchronize];
}

#pragma mark - Orientation management

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation
{
    return YES;
}

#pragma mark - Memory management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"ADDACCOUNT"
                                                  object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"UPDATEACCOUNT"
                                                  object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:self];
    self.manager = nil;
}

@end
