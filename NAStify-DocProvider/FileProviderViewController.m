//
//  FileProviderViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "FileProviderViewController.h"
#import "UserAccount.h"
#import "FileItem.h"
#import "FileProviderBrowserViewController.h"
#import "ServerCell.h"
#import "SSKeychain.h"

@interface FileProviderViewController ()
@end

@implementation FileProviderViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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
    
#ifdef SAMBA
    // Reachability
    self.manager = [AFHTTPRequestOperationManager manager];
    __weak __typeof(self)weakSelf = self;
    
    [self.manager.reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        [weakSelf.tableView reloadData];
    }];
    [self.manager.reachabilityManager startMonitoring];
#endif
}

- (void)viewWillAppear:(BOOL)animated
{
    // Hide toolbar & Navigation bar
    [self.navigationController setToolbarHidden:YES animated:NO];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    
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
#ifdef SAMBA
    return 3;
#else
    return 2;
#endif
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger rows = 0;
    switch (section)
    {
        case 0: // Local
        {
            rows = 1;
            break;
        }
        case 1: // Servers
        {
            rows = [self.accounts count];
            break;
        }
#ifdef SAMBA
        case 2: // SMB/CIFS
        {
            if (self.manager.reachabilityManager.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi)
            {
                rows = 1;
            }
            break;
        }
#endif
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
            sectionName = NSLocalizedString(@"Local",nil);
            break;
        }
        case 1:
        {
            sectionName = NSLocalizedString(@"Servers",nil);
            break;
        }
#ifdef SAMBA
        case 2:
        {
            if (self.manager.reachabilityManager.networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWiFi)
            {
                sectionName = NSLocalizedString(@"Windows Shares (SMB/CIFS)",nil);
            }
            break;
        }
#endif
        default:
            break;
    }
    return sectionName;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * ServerCellIdentifier = @"ServerCell";
    UITableViewCell *cell = nil;
    
    switch (indexPath.section)
    {
        case 0: // Local
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
            UserAccount *localAccount = [[UserAccount alloc] init];
            localAccount.serverType = SERVER_TYPE_LOCAL;
            [serverCell setAccount:localAccount];
            
            serverCell.serverLabel.text = NSLocalizedString(@"Local Files",nil);
            cell = serverCell;
            break;
        }
        case 1: // Servers
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
#ifdef SAMBA
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
            account.accountName = NSLocalizedString(@"Windows Shares", nil);
            [serverCell setAccount:account];
            cell = serverCell;
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    {
        switch (indexPath.section)
        {
            case 0: // Local
            {
                UserAccount *localAccount = [[UserAccount alloc] init];
                localAccount.serverType = SERVER_TYPE_LOCAL;
                
                FileItem *rootFolder = [[FileItem alloc] init];
                rootFolder.isDir = YES;
                rootFolder.path = @"/";
                NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
                rootFolder.fullPath = [containerURL.path stringByAppendingString:@"/Documents/"];
                
                FileProviderBrowserViewController *fileBrowserViewController = [[FileProviderBrowserViewController alloc] init];
                fileBrowserViewController.delegate = self.delegate;
                fileBrowserViewController.validTypes = self.validTypes;
                fileBrowserViewController.userAccount = localAccount;
                fileBrowserViewController.currentFolder = rootFolder;
                fileBrowserViewController.mode = self.mode;
                fileBrowserViewController.fileURL = self.fileURL;
                
                [self.navigationController pushViewController:fileBrowserViewController animated:YES];
                break;
            }
            case 1: // Servers
            {
                FileItem *rootFolder = [[FileItem alloc] init];
                rootFolder.isDir = YES;
                rootFolder.path = @"/";
                rootFolder.objectIds = [NSArray arrayWithObject:kRootID];
                
                FileProviderBrowserViewController *fileBrowserViewController = [[FileProviderBrowserViewController alloc] init];
                fileBrowserViewController.delegate = self.delegate;
                fileBrowserViewController.validTypes = self.validTypes;
                fileBrowserViewController.userAccount = [self.accounts objectAtIndex:indexPath.row];
                fileBrowserViewController.currentFolder = rootFolder;
                fileBrowserViewController.mode = self.mode;
                fileBrowserViewController.fileURL = self.fileURL;
                
                [self.navigationController pushViewController:fileBrowserViewController animated:YES];
                break;
            }
#ifdef SAMBA
            case 2: // SMB/CIFS
            {
                UserAccount *account = [[UserAccount alloc] init];
                account.serverType = SERVER_TYPE_SAMBA;
                
                FileItem *rootFolder = [[FileItem alloc] init];
                rootFolder.isDir = YES;
                rootFolder.path = @"/";
                rootFolder.objectIds = [NSArray arrayWithObject:kRootID];
                
                FileProviderBrowserViewController *fileBrowserViewController = [[FileProviderBrowserViewController alloc] init];
                fileBrowserViewController.delegate = self.delegate;
                fileBrowserViewController.validTypes = self.validTypes;
                fileBrowserViewController.userAccount = account;
                fileBrowserViewController.currentFolder = rootFolder;
                fileBrowserViewController.mode = self.mode;
                fileBrowserViewController.fileURL = self.fileURL;
                
                [self.navigationController pushViewController:fileBrowserViewController animated:YES];
                break;
            }
#endif
            default:
            {
                break;
            }
        }
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - TextFieldDelegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}


#pragma mark - Orientation management

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation
{
    return YES;
}

#pragma mark - Memory management

- (void)dealloc
{
}

@end
