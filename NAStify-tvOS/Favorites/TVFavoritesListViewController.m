//
//  TVFavoritesListViewController.m
//  NAStify-tvOS
//
//  Created by Sylver B
//  Copyright © 2016 Sylver B. All rights reserved.
//

#import "TVFavoritesListViewController.h"
#import "ConnectionManager.h"
#import "TVFileBrowserCollectionViewController.h"
#import "TVFileBrowserTableViewController.h"
#import "ServerTypeViewController.h"
#import "SSKeychain.h"

// Servers settings views
#import "ServerSettingsFreeboxRevViewController.h"
#import "ServerSettingsFtpViewController.h"
#import "ServerSettingsOwnCloudViewController.h"
#import "ServerSettingsQnapViewController.h"
#import "ServerSettingsSambaViewController.h"
#import "ServerSettingsSynologyViewController.h"
#import "ServerSettingsWebDavViewController.h"

#define SECTION_FAVORITES 0

@interface TVFavoritesListViewController ()
@property(nonatomic) NSInteger timeCounter;
@property(nonatomic, strong) NSTimer *longTapTimer;

- (void)longPressAction:(UILongPressGestureRecognizer*)longPressRecognizer;

@end

@implementation TVFavoritesListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"Favorites", nil);

    // Register account changes notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateAccountNotification:)
                                                 name:@"UPDATEACCOUNT"
                                               object:nil];

    self.tableView.layoutMargins = UIEdgeInsetsMake(0, 90, 0, 90);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    NSData * accountsData = [defaults objectForKey:@"favorites"];
    if (!accountsData)
    {
        self.accounts = [[NSMutableArray alloc] init];
    }
    else
    {
        self.accounts = [[NSMutableArray alloc] initWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:accountsData]];
    }
    [self.tableView reloadData];
}

#pragma mark - Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger rows = 0;
    switch (section)
    {
        case SECTION_FAVORITES:
        {
            if (self.accounts.count == 0)
                rows = 1;
            else
                rows = [self.accounts count];
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
        case SECTION_FAVORITES:
        {
            sectionName = NSLocalizedString(@"Favorites",nil);
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
    static NSString * TableViewCellIdentifier = @"TableViewCell";
    static NSString * ServerCellIdentifier = @"ServerCell";
    UITableViewCell *cell = nil;

    switch (indexPath.section)
    {
        case SECTION_FAVORITES:
        {
            if (self.accounts.count)
            {
                ServerCell *serverCell = (ServerCell *)[tableView dequeueReusableCellWithIdentifier:ServerCellIdentifier];
                if (serverCell == nil)
                {
                    serverCell = [[ServerCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:ServerCellIdentifier];
                }

                // Remove long tap gesture recognizer if present
                NSArray *gestureList = [serverCell gestureRecognizers];
                for (id gesture in gestureList)
                {
                    if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]])
                    {
                        [serverCell removeGestureRecognizer:gesture];
                        break;
                    }
                }

                // Tap recognizer
                UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                      action:@selector(longPressAction:)];
                [serverCell addGestureRecognizer:gesture];

                // Configure the cell...
                [serverCell setAccount:[self.accounts objectAtIndex:indexPath.row]];
                cell = serverCell;
            }
            else
            {
                // Last item, show the information message
                cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:TableViewCellIdentifier];
                if (cell == nil)
                {
                    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                  reuseIdentifier:TableViewCellIdentifier];
                }

                // Configure the cell...
                cell.textLabel.text = NSLocalizedString(@"To add a favorite, connect to a server and long tap on a folder", nil);
            }
            break;
        }
        default:
            break;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.accounts.count == 0)
        return;

    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    switch (indexPath.section)
    {
        case SECTION_FAVORITES:
        {
            if (indexPath.row != [self.accounts count])
            {
                UserAccount *account = [self.accounts objectAtIndex:indexPath.row];

                FileItem *rootFolder = [[FileItem alloc] init];
                rootFolder.isDir = YES;
                if ((account.serverType != SERVER_TYPE_WEBDAV) &&
                    (account.settings != nil))
                {
                    NSMutableArray *array = [NSMutableArray arrayWithObject:kRootID];
                    NSString *startPath = [account.settings objectForKey:@"path"];
                    NSArray *componentPath = [startPath componentsSeparatedByString:@"/"];
                    rootFolder.path = @"";
                    for (NSString *component in componentPath)
                    {
                        if (![component isEqualToString:@""])
                        {
                            [array addObject:component];
                            rootFolder.path = [rootFolder.path stringByAppendingFormat:@"/%@",component];
                        }
                    }
                    rootFolder.objectIds = [NSArray arrayWithArray:array];
                }
                else
                {
                    rootFolder.path = @"/";
                    rootFolder.objectIds = [NSArray arrayWithObject:kRootID];
                }

                if ([[defaults objectForKey:kNASTifySettingBrowserType] integerValue] == kNASTifySettingBrowserTypeGrid)
                {
                    FileBrowserCollectionViewController *fileBrowserViewController = [[FileBrowserCollectionViewController alloc] initWithNibName:nil bundle:nil];
                    fileBrowserViewController.userAccount = account;
                    fileBrowserViewController.currentFolder = rootFolder;

                    [self.navigationController pushViewController:fileBrowserViewController animated:YES];
                }
                else
                {
                    FileBrowserTableViewController *fileBrowserViewController = [[FileBrowserTableViewController alloc] init];
                    fileBrowserViewController.userAccount = account;
                    fileBrowserViewController.currentFolder = rootFolder;

                    [self.navigationController pushViewController:fileBrowserViewController animated:YES];
                }
            }
            else
            {
                ServerTypeViewController * stc = [[ServerTypeViewController alloc] initWithStyle:UITableViewStyleGrouped];
                [self.navigationController pushViewController:stc animated:YES];
            }

            break;
        }
        default:
            break;
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Notification Methods

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

- (void)save
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:self.accounts] forKey:@"favorites"];
    [defaults synchronize];
}

#pragma mark - Long tap management

- (void)longPressAction:(UILongPressGestureRecognizer *)tapRecognizer
{
    if (tapRecognizer.state == UIGestureRecognizerStateBegan)
    {
        // Find corresponding cell
        NSIndexPath *indexPath;
        for (NSInteger j = 0; j < [self.tableView numberOfSections]; ++j)
        {
            for (NSInteger i = 0; i < [self.tableView numberOfRowsInSection:j]; ++i)
            {
                NSArray *gestureList = [[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:j]] gestureRecognizers];
                for (id gesture in gestureList)
                {
                    if ([gesture isEqual:tapRecognizer])
                    {
                        indexPath = [NSIndexPath indexPathForRow:i inSection:j];
                        break;
                    }
                }

            }
        }
        if (indexPath && (indexPath.row != NSNotFound) && (indexPath.section != NSNotFound))
        {
            switch (indexPath.section)
            {
                case SECTION_FAVORITES:
                {
                    UserAccount *account = [self.accounts objectAtIndex:indexPath.row];
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:account.accountName
                                                                                   message:NSLocalizedString(@"Action",nil)
                                                                            preferredStyle:UIAlertControllerStyleAlert];

                    UIAlertAction *editAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Edit",nil)
                                                                         style:UIAlertActionStyleDefault
                                                                       handler:^(UIAlertAction * action) {
                                                                           [self editServerAtIndexPath:indexPath];
                                                                           [alert dismissViewControllerAnimated:YES completion:nil];
                                                                       }];
                    UIAlertAction *moveUpAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Move up in list",nil)
                                                                           style:UIAlertActionStyleDefault
                                                                         handler:^(UIAlertAction * action) {
                                                                             [self moveUpServerAtIndexPath:indexPath];
                                                                             [alert dismissViewControllerAnimated:YES completion:nil];
                                                                         }];
                    UIAlertAction *moveDownAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Move down in list",nil)
                                                                             style:UIAlertActionStyleDefault
                                                                           handler:^(UIAlertAction * action) {
                                                                               [self moveDownServerAtIndexPath:indexPath];
                                                                               [alert dismissViewControllerAnimated:YES completion:nil];
                                                                           }];
                    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete",nil)
                                                                           style:UIAlertActionStyleDestructive
                                                                         handler:^(UIAlertAction * action) {
                                                                             [self deleteServerAtIndexPath:indexPath];
                                                                             [alert dismissViewControllerAnimated:YES completion:nil];
                                                                         }];
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                                           style:UIAlertActionStyleCancel
                                                                         handler:^(UIAlertAction * action) {
                                                                             // Do nothing
                                                                             [alert dismissViewControllerAnimated:YES completion:nil];
                                                                         }];
                    [alert addAction:editAction];
                    // If not first server, allow to move up
                    if (indexPath.row > 0)
                    {
                        [alert addAction:moveUpAction];
                    }
                    // If not last server, allow to move down
                    if (indexPath.row < self.accounts.count - 1)
                    {
                        [alert addAction:moveDownAction];
                    }
                    [alert addAction:deleteAction];
                    [alert addAction:cancelAction];
                    [self presentViewController:alert animated:YES completion:nil];
                    break;
                }
                default:
                    break;
            }
        }
    }
}

- (void)moveUpServerAtIndexPath:(NSIndexPath *)indexPath
{
    UserAccount *accountToMove = [self.accounts objectAtIndex:indexPath.row];
    [self.accounts removeObjectAtIndex:indexPath.row];
    [self.accounts insertObject:accountToMove atIndex:indexPath.row - 1];
    [self save];
    // Update
    [self.tableView reloadData];
}

- (void)moveDownServerAtIndexPath:(NSIndexPath *)indexPath
{
    UserAccount *accountToMove = [self.accounts objectAtIndex:indexPath.row];
    [self.accounts removeObjectAtIndex:indexPath.row];
    [self.accounts insertObject:accountToMove atIndex:indexPath.row + 1];
    [self save];
    // Update
    [self.tableView reloadData];
}

- (void)deleteServerAtIndexPath:(NSIndexPath *)indexPath
{
    UserAccount *account = [self.accounts objectAtIndex:indexPath.row];

    // delete entries in keychain
    switch (account.serverType)
    {
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
    [self save];
    // Update
    [self.tableView reloadData];
}

- (void)editServerAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section)
    {
        case SECTION_FAVORITES:
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
                case SERVER_TYPE_OWNCLOUD:
                {
                    ServerSettingsOwnCloudViewController *svc = [[ServerSettingsOwnCloudViewController alloc] initWithStyle:UITableViewStyleGrouped
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
                default:
                {
                    // Nothing to do
                    break;
                }
            }
            break;
        }
    }
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    // Unregister notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UPDATEACCOUNT" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

@end
