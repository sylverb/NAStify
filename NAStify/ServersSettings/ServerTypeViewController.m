//
//  ServerTypeViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServerTypeViewController.h"
#if TARGET_OS_IOS
#import "ServerSettingsBoxViewController.h"
#import "ServerSettingsGoogleDriveViewController.h"
#import "ServerSettingsDropboxViewController.h"
#import "ServerSettingsMegaViewController.h"
#import "ServerSettingsOneDriveViewController.h"
#import "ServerSettingsOwnCloudViewController.h"
#endif
#import "ServerSettingsWebDavViewController.h"
#import "ServerSettingsFreeboxRevViewController.h"
#import "ServerSettingsFtpViewController.h"
#import "ServerSettingsSambaViewController.h"
#import "ServerSettingsSynologyViewController.h"
#import "ServerSettingsQnapViewController.h"

#import "ServerTypeCell.h"

@implementation ServerTypeViewController

#if TARGET_OS_IOS
#define ROW_INDEX_BOX           0
#define ROW_INDEX_DROPBOX       1
#define ROW_INDEX_FREEBOX       2
#define ROW_INDEX_FTP           3
#define ROW_INDEX_GOOGLEDRIVE   4
#define ROW_INDEX_MEGA          5
#define ROW_INDEX_ONEDRIVE      6
#define ROW_INDEX_OWNCLOUD      7
#define ROW_INDEX_QNAP          8
#define ROW_INDEX_SYNOLOGY      9
#define ROW_INDEX_WEBDAV        10
#ifdef SAMBA
#define ROW_INDEX_SAMBA         11
#endif
//#define ROW_INDEX_PYDIO         8

// Update this when adding new server types !!!
#ifdef SAMBA
#define NUMBER_OF_ROWS      ROW_INDEX_SAMBA + 1
#else
#define NUMBER_OF_ROWS      ROW_INDEX_WEBDAV + 1
#endif
#else
// AppleTV
#define ROW_INDEX_FREEBOX       0
#define ROW_INDEX_FTP           1
#define ROW_INDEX_SYNOLOGY      2
#define ROW_INDEX_QNAP          3
#define ROW_INDEX_SAMBA         4
#define ROW_INDEX_WEBDAV        5
// Update this when adding new server types !!!
#define NUMBER_OF_ROWS      ROW_INDEX_WEBDAV + 1
#endif

- (void)viewDidLoad
{
    [super viewDidLoad];
    
#if TARGET_OS_IOS
    [self.navigationItem setHidesBackButton:YES];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel 
                                                                                          target:self 
                                                                                          action:@selector(cancelButtonAction)];
#endif
    
    self.navigationItem.title = NSLocalizedString(@"Server Type",nil);
}

#pragma mark -
#pragma mark Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
#if TARGET_OS_IOS
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        return 120.0;
    }
    else
    {
        return 60.0;
    }
#elif TARGET_OS_TV
    return 120;
#endif
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return NUMBER_OF_ROWS;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    static NSString *serverTypeCellIdentifier = @"serverTypeCell";
    
    ServerTypeCell *cell = (ServerTypeCell *)[tableView dequeueReusableCellWithIdentifier:serverTypeCellIdentifier];
    if (cell == nil)
    {
        cell = [[ServerTypeCell alloc] initWithStyle:UITableViewCellStyleDefault
                                     reuseIdentifier:serverTypeCellIdentifier];
    }
    
    // Configure the cell...
    switch (indexPath.row)
    {
        case ROW_INDEX_WEBDAV:
        {
            cell.serverType = SERVER_TYPE_WEBDAV;
            break;
        }
        case ROW_INDEX_FTP:
        {
            cell.serverType = SERVER_TYPE_FTP;
            break;
        }
        case ROW_INDEX_SYNOLOGY:
        {
            cell.serverType = SERVER_TYPE_SYNOLOGY;
            break;
        }
        case ROW_INDEX_FREEBOX:
        {
            cell.serverType = SERVER_TYPE_FREEBOX_REVOLUTION;
            break;
        }
        case ROW_INDEX_QNAP:
        {
            cell.serverType = SERVER_TYPE_QNAP;
            break;
        }
#if TARGET_OS_IOS
        case ROW_INDEX_DROPBOX:
        {
            cell.serverType = SERVER_TYPE_DROPBOX;
            break;
        }
        case ROW_INDEX_SAMBA:
        {
            cell.serverType = SERVER_TYPE_SAMBA;
            break;
        }
        case ROW_INDEX_BOX:
        {
            cell.serverType = SERVER_TYPE_BOX;
            break;
        }
        case ROW_INDEX_GOOGLEDRIVE:
        {
            cell.serverType = SERVER_TYPE_GOOGLEDRIVE;
            break;
        }
        case ROW_INDEX_MEGA:
        {
            cell.serverType = SERVER_TYPE_MEGA;
            break;
        }
        case ROW_INDEX_ONEDRIVE:
        {
            cell.serverType = SERVER_TYPE_ONEDRIVE;
            break;
        }
        case ROW_INDEX_OWNCLOUD:
        {
            cell.serverType = SERVER_TYPE_OWNCLOUD;
            break;
        }
//        case ROW_INDEX_PYDIO:
//        {
//            cell.serverType = SERVER_TYPE_PYDIO;
//            break;
//        }
#endif
        default:
            break;
    }
    
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.row)
    {
        case ROW_INDEX_WEBDAV:
        {
            ServerSettingsWebDavViewController * svc = [[ServerSettingsWebDavViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                      andAccount:nil
                                                                                                        andIndex:-1];
            svc.userAccount.serverType = SERVER_TYPE_WEBDAV;
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
        case ROW_INDEX_FTP:
        {
            ServerSettingsFtpViewController * svc = [[ServerSettingsFtpViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                andAccount:nil
                                                                                                  andIndex:-1];
            svc.userAccount.serverType = SERVER_TYPE_FTP;
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
        case ROW_INDEX_SYNOLOGY:
        {
            ServerSettingsSynologyViewController * svc = [[ServerSettingsSynologyViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                          andAccount:nil
                                                                                                            andIndex:-1];
            svc.userAccount.serverType = SERVER_TYPE_SYNOLOGY;
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
        case ROW_INDEX_FREEBOX:
        {
            ServerSettingsFreeboxRevViewController * svc = [[ServerSettingsFreeboxRevViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                              andAccount:nil
                                                                                                                andIndex:-1];
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
#if TARGET_OS_IOS
//        case ROW_INDEX_PYDIO:
//        {
//            ServerSettingsQnapViewController * svc = [[ServerSettingsQnapViewController alloc] initWithStyle:UITableViewStyleGrouped
//                                                                                                  andAccount:nil
//                                                                                                    andIndex:-1];
//            svc.userAccount.serverType = SERVER_TYPE_PYDIO;
//            [self.navigationController pushViewController:svc animated:YES];
//            break;
//        }
#endif
        case ROW_INDEX_QNAP:
        {
            ServerSettingsQnapViewController * svc = [[ServerSettingsQnapViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                  andAccount:nil
                                                                                                    andIndex:-1];
            svc.userAccount.serverType = SERVER_TYPE_QNAP;
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
#if TARGET_OS_IOS
        case ROW_INDEX_DROPBOX:
        {
            ServerSettingsDropboxViewController *svc = [[ServerSettingsDropboxViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                       andAccount:nil
                                                                                                         andIndex:-1];
            svc.userAccount.serverType = SERVER_TYPE_DROPBOX;
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
        case ROW_INDEX_BOX:
        {
            ServerSettingsBoxViewController *svc = [[ServerSettingsBoxViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                               andAccount:nil
                                                                                                 andIndex:-1];
            svc.userAccount.serverType = SERVER_TYPE_BOX;
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
        case ROW_INDEX_GOOGLEDRIVE:
        {
            ServerSettingsGoogleDriveViewController *svc =
            [[ServerSettingsGoogleDriveViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                andAccount:nil
                                                                  andIndex:-1];
            svc.userAccount.serverType = SERVER_TYPE_GOOGLEDRIVE;
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
        case ROW_INDEX_MEGA:
        {
            ServerSettingsMegaViewController *svc =
            [[ServerSettingsMegaViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                         andAccount:nil
                                                           andIndex:-1];
            svc.userAccount.serverType = SERVER_TYPE_MEGA;
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
        case ROW_INDEX_ONEDRIVE:
        {
            ServerSettingsOneDriveViewController *svc =
            [[ServerSettingsOneDriveViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                             andAccount:nil
                                                               andIndex:-1];
            svc.userAccount.serverType = SERVER_TYPE_ONEDRIVE;
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
        case ROW_INDEX_OWNCLOUD:
        {
            ServerSettingsOwnCloudViewController *svc =
            [[ServerSettingsOwnCloudViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                             andAccount:nil
                                                               andIndex:-1];
            svc.userAccount.serverType = SERVER_TYPE_OWNCLOUD;
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
#endif
        case ROW_INDEX_SAMBA:
        {
            ServerSettingsSambaViewController * svc = [[ServerSettingsSambaViewController alloc] initWithStyle:UITableViewStyleGrouped
                                                                                                    andAccount:nil
                                                                                                      andIndex:-1];
            svc.userAccount.serverType = SERVER_TYPE_SAMBA;
            [self.navigationController pushViewController:svc animated:YES];
            break;
        }
        default:
            break;
    }
}

- (void)cancelButtonAction
{
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end

