//
//  FileBrowserTableViewController.m
//  NAStify-tvOS
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2015 CodeIsALie. All rights reserved.
//

#import <AVKit/AVKit.h>
#import "TVFileBrowserTableViewController.h"
#import "FileItem.h"
#import "SSKeychain.h"
#import "SVProgressHUD.h"

// File viewers
#import "TVCustomMoviePlayerViewController.h"
#import "VLCPlaybackController.h"
#import "VLCPlayerDisplayController.h"
#import "VLCFullscreenMovieTVViewController.h"

#import "private.h"

@interface FileBrowserTableViewController (Private)
- (void)triggerReconnect;
- (BOOL)getSubtitleFileForMedia:(FileItem *)media;
@end

@interface FileBrowserTableViewController ()
{
    VLCMediaPlayer *_mediaplayer;
}

@property(nonatomic, strong) UILongPressGestureRecognizer *longTapGesture;
- (void)longPressAction:(UILongPressGestureRecognizer*)longPressRecognizer;
@end

@implementation FileBrowserTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self)
    {
        self.isConnected = FALSE;
        self.filesListIsValid = FALSE;
        self.tableViewIsUpdating = FALSE;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (!self.connectionManager)
    {
        self.connectionManager = [[ConnectionManager alloc] init];
        self.connectionManager.userAccount = self.userAccount;
    }

    NSString *title = [[self.currentFolder.path componentsSeparatedByString:@"/"] lastObject];
    if ([title isEqualToString:@""])
    {
        title = @"/";
    }
    self.navigationItem.title = title;
    
    self.filteredFilesArray = [[NSMutableArray alloc] init];
    
    self.tableView.layoutMargins = UIEdgeInsetsMake(0, 90, 0, 90);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(triggerReconnect)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    if ([defaults objectForKey:@"sortingType"])
    {
        self.sortingType = (FileItemSortType)[[defaults objectForKey:@"sortingType"] integerValue];
    }
    else
    {
        self.sortingType = SORT_BY_NAME_DESC_FOLDER_FIRST;
    }
    
    if ([self.filesArray count] != 0)
    {
        [self.filesArray sortFileItemArrayWithOrder:self.sortingType];
        [self.tableView reloadData];
    }
    
    if ([defaults objectForKey:@"showHidden"])
    {
        self.showHidden = [[defaults objectForKey:@"showHidden"] boolValue];
    }
    else
    {
        self.showHidden = NO;
    }
    
    // Tap recognizer
    self.longTapGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(longPressAction:)];
    self.longTapGesture.minimumPressDuration = 1;
    [self.view addGestureRecognizer:self.longTapGesture];
#if 0
    // Delete cached files if needed
    NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
    NSString *cacheFolder = [containerURL.path stringByAppendingString:@"/Cache/"];
    
    NSDirectoryEnumerator* en = [[NSFileManager defaultManager] enumeratorAtPath:cacheFolder];
    
    NSString* file;
    while (file = [en nextObject])
    {
        [[NSFileManager defaultManager] removeItemAtPath:[cacheFolder stringByAppendingPathComponent:file] error:NULL];
    }
#endif
}

- (void)viewDidAppear:(BOOL)animated
{
    self.connectionManager.delegate = self;
    
	if (([self.currentFolder.path isEqualToString:@"/"]) || (self.isConnected == NO))
    {
		if (([self.filesArray count] == 0) && (!self.isConnected))
        {
            // Login
            BOOL needToWaitLogin = NO;
            needToWaitLogin = [self.connectionManager login];
            
			// Get file list if possible
            if (!needToWaitLogin)
            {
                self.isConnected = YES;
                
                [self.connectionManager listForPath:self.currentFolder];
            }
        }
        else if (self.userAccount.serverType == SERVER_TYPE_LOCAL)
        {
            // Get file list
            [self.connectionManager listForPath:self.currentFolder];
        }
	}
    else if ([self.filesArray count] == 0)
    {
		// Get file list
		[self.connectionManager listForPath:self.currentFolder];
	}
    else if (self.userAccount.serverType == SERVER_TYPE_LOCAL)
    {
		// Get file list (we are with local files, it costs nothing to reload here)
		[self.connectionManager listForPath:self.currentFolder];
    }
    
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    NSArray *viewControllers = self.navigationController.viewControllers;
    if ((viewControllers.count > 1) &&
        ([viewControllers objectAtIndex:viewControllers.count-2] == self))
    {
        // We are pushing a new view, nothing to do
    }
    else if ((![viewControllers containsObject:self]) && (viewControllers.count == 1) && self.isConnected)
    {
        // We are going back to servers list, logout from server
        [self.connectionManager logout];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    
    [self.view removeGestureRecognizer:self.longTapGesture];

    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

#pragma mark - Download management

- (BOOL)getSubtitleFileForMedia:(FileItem *)media
{
    NSString *urlTemp = [media.name stringByDeletingPathExtension];
    NSMutableArray *fileList = [[NSMutableArray alloc] init];
    for (FileItem *file in self.filesArray)
    {
        if ([[file.name stringByDeletingPathExtension] hasPrefix:urlTemp])
        {
            [fileList addObject:file];
        }
    }
    
    NSUInteger options = NSRegularExpressionSearch | NSCaseInsensitiveSearch;
    for (FileItem *file in fileList)
    {
        if ([file.name rangeOfString:kSupportedSubtitleFileExtensions options:options].location != NSNotFound)
        {
            {
                self.downloadAction = DOWNLOAD_ACTION_SUBTITLE;
#if 0
                MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                          animated:YES];
                if ([self.connectionManager pluginRespondsToSelector:@selector(cancelDownloadTask)])
                {
                    hud.allowsCancelation = YES;
                    hud.tag = TAG_HUD_DOWNLOAD;
                }
                hud.delegate = self;
                hud.labelText = NSLocalizedString(@"Preparing subtitle", nil);
#endif
                self.dlFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"tempSubtitle"];
                [self.connectionManager downloadFile:file
                                         toLocalName:self.dlFilePath];
            }
            return YES;
        }
    }
    return NO;
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80;
}

- (UITableView *)activeTableView
{
    UITableView *tableView = nil;
    tableView = self.tableView;
    
    return tableView;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    if ((self.filesListIsValid) &&
        ([self.filesArray count] == 0) &&
        (!self.tableViewIsUpdating))
    {
        // No files here, put a cell to tell it
        return 1;
    }
    else
    {
        return [self.filesArray count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *FileBrowserCellIdentifier = @"FileBrowserCell";
    static NSString * TableViewCellIdentifier = @"TableViewCell";

    if ((self.filesListIsValid) && ([self.filesArray count] == 0))
    {
        UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:TableViewCellIdentifier];
        if (cell == nil)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:TableViewCellIdentifier];
        }
        
        // Configure the cell...
        cell.textLabel.text = NSLocalizedString(@"No file here", nil);
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        return cell;
    }
    else
    {
        FileItem *fileItem = nil;
        fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);
        
        FileBrowserCell *fileBrowserCell = (FileBrowserCell *)[tableView dequeueReusableCellWithIdentifier:FileBrowserCellIdentifier];
        if (fileBrowserCell == nil)
        {
            fileBrowserCell = [[FileBrowserCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                     reuseIdentifier:FileBrowserCellIdentifier];
        }
        
        // Configure the cell...
        [fileBrowserCell setFileItem:fileItem
                        withDelegate:self
                              andTag:TAG_TEXTFIELD_FILENAME];
        
        return fileBrowserCell;
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.filesArray count] != 0)
    {
        FileItem *fileItem = nil;
        fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);

        // Show file if possible
        if (![self openFile:fileItem])
        {
            // For not handled types, show action menu
//          [self showActionMenuForItemAtIndexPath:indexPath];
        }
        // deselect the cell
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - Long tap management

- (void)showAlertMessage:(NSString *)alertMessage
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Warning", nil)
                                                                   message:alertMessage
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {
                                                             // Do nothing
                                                             [alert dismissViewControllerAnimated:YES completion:nil];
                                                         }];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)longPressAction:(UILongPressGestureRecognizer *)tapRecognizer
{
    BOOL showAlert = NO;

    if (tapRecognizer.state == UIGestureRecognizerStateBegan)
    {
        for (UITableViewCell *cell in self.tableView.visibleCells)
        {
            if (cell.isFocused)
            {
                BOOL canDelete = NO;
                NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
                FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);

                UIAlertController *alert = [UIAlertController alertControllerWithTitle:fileItem.name
                                                                               message:NSLocalizedString(@"Action",nil)
                                                                        preferredStyle:UIAlertControllerStyleAlert];


                if (((fileItem.isDir)&&(ServerSupportsFeature(FolderDelete))) ||
                    ((!fileItem.isDir)&&(ServerSupportsFeature(FileDelete))))
                {
                    canDelete = fileItem.writeAccess;
                }

                if (fileItem.isDir)
                {
                    showAlert = YES;
                    UIAlertAction *favoriteAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Add as favorite",nil)
                                                                             style:UIAlertActionStyleDefault
                                                                           handler:^(UIAlertAction * action) {
                                                                               NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
                                                                               // Copy current account and change uuid
                                                                               UserAccount *favorite = [self.userAccount copy];
                                                                               favorite.uuid = [NSString generateUUID];

                                                                               favorite.accountName = [NSString stringWithFormat:@"%@ (%@)",favorite.accountName,fileItem.fullPath];
                                                                               favorite.settings = [NSDictionary dictionaryWithObject:fileItem.fullPath forKey:@"path"];
                                                                               // Copy password
                                                                               NSString *password;
                                                                               if (self.userAccount.password.length != 0)
                                                                                   password = self.userAccount.password;
                                                                               else
                                                                                   password = [SSKeychain passwordForService:self.userAccount.uuid account:@"password"];
                                                                               if (password.length != 0)
                                                                               {
                                                                                   [SSKeychain setPassword:password
                                                                                                forService:favorite.uuid
                                                                                                   account:@"password"];
                                                                               }

                                                                               NSData *accountsData = [defaults objectForKey:@"favorites"];
                                                                               NSMutableArray *accounts;
                                                                               if (!accountsData)
                                                                               {
                                                                                   accounts = [[NSMutableArray alloc] init];
                                                                               }
                                                                               else
                                                                               {
                                                                                   accounts = [[NSMutableArray alloc] initWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:accountsData]];
                                                                               }
                                                                               [accounts addObject:favorite];
                                                                               [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:accounts] forKey:@"favorites"];
                                                                               [defaults synchronize];
                                                                           }];
                    [alert addAction:favoriteAction];
                }
                if (canDelete)
                {
                    showAlert = YES;
                    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete",nil)
                                                                           style:UIAlertActionStyleDestructive
                                                                         handler:^(UIAlertAction * action) {
                                                                             NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];

                                                                             if ([defaults boolForKey:kNASTifySettingAllowDelete])
                                                                             {
                                                                                 [self.tableView beginUpdates];
                                                                                 self.tableViewIsUpdating = YES;
                                                                                 [self.filesArray removeObjectAtIndex:indexPath.row];
                                                                                 [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                                                                                       withRowAnimation:UITableViewRowAnimationFade];
                                                                                 [self.tableView endUpdates];
                                                                                 self.tableViewIsUpdating = NO;

                                                                                 [self.connectionManager deleteFiles:@[fileItem]];
                                                                                 [alert dismissViewControllerAnimated:YES completion:nil];
                                                                             }
                                                                             else
                                                                             {
                                                                                 [self showAlertMessage:NSLocalizedString(@"You have to enable delete in setting", nil)];
                                                                                 [alert dismissViewControllerAnimated:YES completion:nil];
                                                                             }
                                                                         }];
                    [alert addAction:deleteAction];
                }

                if (showAlert)
                {
                    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                                           style:UIAlertActionStyleCancel
                                                                         handler:^(UIAlertAction * action) {
                                                                             // Do nothing
                                                                             [alert dismissViewControllerAnimated:YES completion:nil];
                                                                         }];
                    
                    [alert addAction:cancelAction];
                    alert.preferredAction = cancelAction;
                    [self presentViewController:alert animated:YES completion:nil];
                }
                break;
            }
        }
    }
}

#pragma mark - File management

- (void)showMovieViewController
{
    VLCFullscreenMovieTVViewController *moviewVC = [VLCFullscreenMovieTVViewController fullscreenMovieTVViewController];
    [self presentViewController:moviewVC
                       animated:YES
                     completion:nil];
}

- (void)showVLCPlayerForFile:(FileItem *)fileItem withSubtitles:(NSString *)subPath
{
    NSDictionary *optionsDict;
    [VLCPlayerDisplayController sharedInstance].displayMode = VLCPlayerDisplayControllerDisplayModeFullscreen;
    
    NetworkConnection *connection = [self.connectionManager urlForVideo:fileItem];
    VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
    switch (connection.urlType)
    {
        case URLTYPE_SMB:
        {
            optionsDict = @{@"smb-user" : connection.user ?: @"",
                            @"smb-pwd" : connection.password ?: @"",
                            @"smb-domain" : connection.workgroup ?: @"WORKGROUP"};
            break;
        }
        case URLTYPE_FTP:
        {
            optionsDict = @{@"ftp-user" : connection.user ?: @"",
                            @"sftp-user" : connection.user ?: @"",
                            @"ftp-pwd" : connection.password ?: @"",
                            @"sftp-pwd" : connection.password ?: @""};
            break;
        }
        default:
            break;
    }
    if ((fileItem.fileType == FILETYPE_VLC_AUDIO) || (fileItem.fileType == FILETYPE_QT_AUDIO))
    {
        NSInteger index = 0;
        NSInteger fileIndex = 0;
        // Find index of file
        for (FileItem *file in self.filesArray)
        {
            if ((file.fileType == FILETYPE_VLC_AUDIO) || (file.fileType == FILETYPE_QT_AUDIO))
            {
                if (file == fileItem)
                {
                    fileIndex = index;
                    break;
                }
                index++;
            }
        }
        // For some reason the media list is played in reverse order, so store them in
        // reversed order ...
        VLCMediaList *mediaList = [[VLCMediaList alloc] init];
        for (index = self.filesArray.count-1; index >= 0; index--)
        {
            FileItem *file = [self.filesArray objectAtIndex:index];
            if ((file.fileType == FILETYPE_VLC_AUDIO) || (file.fileType == FILETYPE_QT_AUDIO))
            {
                NetworkConnection *cnx = [self.connectionManager urlForVideo:file];
                
                VLCMedia *media = [VLCMedia mediaWithURL:cnx.url];
                [media setMetadata:file.name forKey:VLCMetaInformationTitle];
                [media addOptions:optionsDict];
                [mediaList addMedia:media];
            }
        }
        [vpc playMediaList:mediaList firstIndex:fileIndex];
    }
    else
    {
        if (subPath)
        {
            vpc.customMediaOptionsDictionary = optionsDict;
            [vpc playURL:connection.url subtitlesFilePath:subPath];
        }
        else
        {
            NSInteger index = 0;
            NSInteger fileIndex = 0;
            // Find index of file
            for (FileItem *file in self.filesArray)
            {
                if ((file.fileType == FILETYPE_VLC_VIDEO) || (file.fileType == FILETYPE_QT_VIDEO))
                {
                    if (file == fileItem)
                    {
                        fileIndex = index;
                        break;
                    }
                    index++;
                }
            }
            // For some reason the media list is played in reverse order, so store them in
            // reversed order ...
            VLCMediaList *mediaList = [[VLCMediaList alloc] init];
            for (index = self.filesArray.count-1; index >= 0; index--)
            {
                FileItem *file = [self.filesArray objectAtIndex:index];
                if ((file.fileType == FILETYPE_VLC_VIDEO) || (file.fileType == FILETYPE_QT_VIDEO))
                {
                    NetworkConnection *cnx = [self.connectionManager urlForVideo:file];
                    
                    VLCMedia *media = [VLCMedia mediaWithURL:cnx.url];
                    [media setMetadata:file.name forKey:VLCMetaInformationTitle];
                    [media addOptions:optionsDict];
                    [mediaList addMedia:media];
                }
            }
            [vpc playMediaList:mediaList firstIndex:fileIndex];
        }
    }
    
    [self showMovieViewController];
}

- (BOOL)openFile:(FileItem *)fileItem
{
    BOOL itemHandled = NO;
    switch ([fileItem fileType])
    {
        case FILETYPE_FOLDER:
        {
            itemHandled = YES;
            FileBrowserTableViewController *fileBrowserViewController = [[FileBrowserTableViewController alloc] init];
            fileBrowserViewController.isConnected = TRUE;
            fileBrowserViewController.currentFolder = fileItem;
            fileBrowserViewController.userAccount = self.userAccount; // Not needed, may be useful for future needs
            fileBrowserViewController.connectionManager = self.connectionManager;
            [self.navigationController pushViewController:fileBrowserViewController animated:YES];
            break;
        }
        case FILETYPE_VLC_VIDEO:
        case FILETYPE_VLC_AUDIO:
        {
            if (ServerSupportsFeature(VLCPlayer))
            {
                itemHandled = YES;
                self.videoFile = fileItem;
                
                if (![self getSubtitleFileForMedia:fileItem])
                {
                    [self showVLCPlayerForFile:fileItem withSubtitles:nil];
                }
            }
            break;
        }
        case FILETYPE_QT_VIDEO:
        case FILETYPE_QT_AUDIO:
        {
            if (([self.connectionManager pluginRespondsToSelector:@selector(urlForFile:)]) ||
                ([self.connectionManager pluginRespondsToSelector:@selector(urlForVideo:)]))
            {
                NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
                if ((([[defaults objectForKey:kNASTifySettingInternalPlayer] integerValue] == kNASTifySettingInternalPlayerTypeVLCOnly) && (ServerSupportsFeature(VLCPlayer))))
                {
                    // Use VLC player
                    itemHandled = YES;
                    
                    self.videoFile = fileItem;
                    
                    if (![self getSubtitleFileForMedia:fileItem])
                    {
                        [self showVLCPlayerForFile:fileItem withSubtitles:nil];
                    }
                }
                else if (ServerSupportsFeature(QTPlayer))
                {
                    itemHandled = YES;
                    // Internal player can handle this media
                    CustomMoviePlayerViewController *mp = [[CustomMoviePlayerViewController alloc] init];
                    mp.filename = fileItem.name;
                    mp.allowsAirPlay = NO;
                    mp.url = [self.connectionManager urlForVideo:fileItem].url;
                    if (mp)
                    {
                        [self presentViewController:mp animated:YES completion:nil];
                    }
                }
                else if (ServerSupportsFeature(VLCPlayer))
                {
                    itemHandled = YES;
                    // Fallback to VLC media player
                    if (![self getSubtitleFileForMedia:fileItem])
                    {
                        [self showVLCPlayerForFile:fileItem withSubtitles:nil];
                    }
                }
            }
            break;
        }
        case FILETYPE_UNKNOWN:
        default:
        {
            if (self.userAccount.serverType == SERVER_TYPE_UPNP)
            {
                // As some UPnP servers are not providing extensions, use VLC to open unknown files
                itemHandled = YES;
                self.videoFile = fileItem;
                
                if (![self getSubtitleFileForMedia:fileItem])
                {
                    [self showVLCPlayerForFile:fileItem withSubtitles:nil];
                }
            }
            break;
        }
    }
    return itemHandled;
}

#pragma mark - Reconnection delegate

- (void)triggerReconnect
{
    [self.connectionManager reconnect];
}

#pragma mark - OTP (2-Step authentication) support

- (void)sendOTP:(NSString *)otp
{
    [self.connectionManager sendOTP:otp];
}

- (void)sendOTPEmergencyCode
{
    [self.connectionManager sendOTPEmergencyCode];
}

#pragma mark - ConnectionManager protocol

- (void)CMAction:(NSDictionary *)dict
{
    // If there is a message, show it
    if ([dict objectForKey:@"message"])
    {
        // Hide current alert to show the new one
        if ([self.presentedViewController isKindOfClass:[UIAlertController class]])
        {
            [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[dict objectForKey:@"title"]
                                                                       message:[dict objectForKey:@"message"]
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  [alert dismissViewControllerAnimated:YES completion:nil];
                                                              }];
        [alert addAction:defaultAction];
        if ([[dict objectForKey:@"action"] integerValue] == BROWSER_ACTION_QUIT_SERVER)
        {
            [self.navigationController popToRootViewControllerAnimated:YES];
            [self.navigationController presentViewController:alert animated:YES completion:nil];
        }
        else
        {
            [self presentViewController:alert animated:YES completion:nil];
        }
    }

    if ([dict objectForKey:@"action"])
    {
        switch ([[dict objectForKey:@"action"] integerValue])
        {
            case BROWSER_ACTION_QUIT_SERVER:
            {
                // Go back to servers list
                [self.navigationController popToRootViewControllerAnimated:YES];
                break;
            }
            case BROWSER_ACTION_DO_NOTHING:
            default:
            {
                break;
            }
        }

    }
}

- (void)CMLogin:(NSDictionary *)dict
{
    // If login is ok, request list
    if ([[dict objectForKey:@"success"] boolValue])
    {
        // Request list
        self.isConnected = TRUE;
        [self.connectionManager listForPath:self.currentFolder];
    }
    else
    {
        // Hide current alert to show the new one
        if ([self.presentedViewController isKindOfClass:[UIAlertController class]])
        {
            [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        }
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Login",nil)
                                                                       message:NSLocalizedString([dict objectForKey:@"error"],nil)
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  [alert dismissViewControllerAnimated:YES completion:nil];
                                                                  // Go back to servers list
                                                                  [self.navigationController popToRootViewControllerAnimated:YES];

                                                              }];


        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)CMLogout:(NSDictionary *)dict
{
    if (self.isConnected)
    {
        self.isConnected = FALSE;
        [self.navigationController popViewControllerAnimated:YES];

        [SVProgressHUD dismiss];
    }
}

- (void)CMRequestOTP:(NSNotification *)notification
{
    // Hide current alert to show the new one
    if ([self.presentedViewController isKindOfClass:[UIAlertController class]])
    {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"2-Factor Authentication",nil)
                                                                   message:NSLocalizedString(@"Enter 6-digit code or 8-digit emergency code",nil)
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   UITextField *textField = alert.textFields[0];
                                                   [self sendOTP:textField.text];

                                                   [alert dismissViewControllerAnimated:YES completion:nil];
                                               }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       // Go back to servers list
                                                       [self.navigationController popToRootViewControllerAnimated:YES];
                                                       [alert dismissViewControllerAnimated:YES completion:nil];
                                                   }];

    [alert addAction:ok];
    [alert addAction:cancel];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"code",nil);
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)CMFilesList:(NSDictionary *)dict
{
    // Check if the notification is for this folder
    if ((([dict objectForKey:@"path"]) && ([self.currentFolder.path isEqualToString:[dict objectForKey:@"path"]])) ||
        (([dict objectForKey:@"id"]) && ([[self.currentFolder.objectIds lastObject] isEqual:[dict objectForKey:@"id"]])))
    {
        self.filesListIsValid = TRUE;
        if ([[dict objectForKey:@"success"] boolValue])
        {
            self.isConnected = TRUE;

            NSArray *filesList = [dict objectForKey:@"filesList"];

            self.filesArray = [[NSMutableArray alloc] init];

            for (NSDictionary *element in filesList)
            {
                FileItem *fileItem = [[FileItem alloc] init];
                fileItem.name = [element objectForKey:@"filename"];
                if (self.showHidden || ![fileItem.name hasPrefix:@"."])
                {
                    fileItem.isDir = [[element objectForKey:@"isdir"] boolValue];
                    fileItem.shortPath = self.currentFolder.path;
                    if ([self.currentFolder.path isEqualToString:@"/"])
                    {
                        fileItem.path = [@"/" stringByAppendingPathComponent:fileItem.name]; // Path to file
                    }
                    else
                    {
                        fileItem.path = [self.currentFolder.path stringByAppendingPathComponent:fileItem.name]; // Path to file
                    }
                    if ([element objectForKey:@"path"])
                    {
                        fileItem.fullPath = [element objectForKey:@"path"]; // Path with filename/foldername
                    }
                    else
                    {
                        fileItem.fullPath = fileItem.path;
                    }

                    if ([element objectForKey:@"id"])
                    {
                        fileItem.objectIds = [self.currentFolder.objectIds arrayByAddingObject:[element objectForKey:@"id"]];
                    }
                    else
                    {
                        fileItem.objectIds = self.currentFolder.objectIds;
                    }

                    if ([element objectForKey:@"iscompressed"])
                    {
                        fileItem.isCompressed = [[element objectForKey:@"iscompressed"] boolValue];
                    }
                    else
                    {
                        fileItem.isCompressed = NO;
                    }

                    if (fileItem.isDir)
                    {
                        fileItem.fileSize = nil;
                        fileItem.fileSizeNumber = nil;
                        fileItem.owner = [element objectForKey:@"owner"];
                        if ([element objectForKey:@"isejectable"])
                        {
                            fileItem.isEjectable = [[element objectForKey:@"isejectable"] boolValue];
                        }
                        else
                        {
                            fileItem.isEjectable = NO;
                        }
                    }
                    else
                    {
                        if ([element objectForKey:@"type"])
                        {
                            fileItem.type = [element objectForKey:@"type"];
                        }
                        else
                        {
                            fileItem.type = [[fileItem.name componentsSeparatedByString:@"."] lastObject];
                        }

                        if ([element objectForKey:@"filesizenumber"])
                        {
                            fileItem.fileSizeNumber = [element objectForKey:@"filesizenumber"];
                        }
                        else
                        {
                            fileItem.fileSizeNumber = nil;
                        }
                        fileItem.fileSize = [[element objectForKey:@"filesizenumber"] stringForNumberOfBytes];

                        fileItem.owner = [element objectForKey:@"owner"];

                        fileItem.isEjectable = NO;
                    }
                    fileItem.writeAccess = [[element objectForKey:@"writeaccess"] boolValue];

                    /* Date */
                    if (([element objectForKey:@"date"]) &&
                        ([[element objectForKey:@"date"] doubleValue] != 0))
                    {
                        fileItem.fileDateNumber = [NSNumber numberWithDouble:[[element objectForKey:@"date"] doubleValue]];
                        NSTimeInterval mtime = (NSTimeInterval)[[element objectForKey:@"date"] doubleValue];
                        NSDate *mdate = [NSDate dateWithTimeIntervalSince1970:mtime];
                        NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
                        [formatter setDateStyle:NSDateFormatterMediumStyle];
                        [formatter setTimeStyle:NSDateFormatterShortStyle];

                        fileItem.fileDate = [formatter stringFromDate:mdate];
                    }

                    /* DownloadURL */
                    if ([element objectForKey:@"url"])
                    {
                        fileItem.downloadUrl = [element objectForKey:@"url"];
                    }

                    [self.filesArray addObject:fileItem];
                }
            }

            if (self.filesArray.count == 0)
            {
                // Hide current alert to show the new one
                if ([self.presentedViewController isKindOfClass:[UIAlertController class]])
                {
                    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
                }
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Browse",nil)
                                                                               message:NSLocalizedString(@"No file in this folder",nil)
                                                                        preferredStyle:UIAlertControllerStyleAlert];

                UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                                        style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * action) {
                                                                          [alert dismissViewControllerAnimated:YES completion:nil];
                                                                          [self.navigationController popViewControllerAnimated:YES];
                                                                      }];
                [alert addAction:defaultAction];
                [self presentViewController:alert animated:YES completion:nil];
            }
            else
            {
                // Sort files array
                [self.filesArray sortFileItemArrayWithOrder:self.sortingType];
            }
        }
        else
        {
            // Hide current alert to show the new one
            if ([self.presentedViewController isKindOfClass:[UIAlertController class]])
            {
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            }
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Browse",nil)
                                                                           message:NSLocalizedString([dict objectForKey:@"error"],nil)
                                                                    preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {
                                                                      [alert dismissViewControllerAnimated:YES completion:nil];
                                                                      [self.navigationController popViewControllerAnimated:YES];
                                                                  }];
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
        }

        // Refresh data
        [self.tableView reloadData];
    }
}

- (void)CMRootObject:(NSDictionary *)dict
{
    // This is used to replace the default root ID with the one retrieved here
    if ([dict objectForKey:@"rootId"])
    {
        self.currentFolder.objectIds = [NSArray arrayWithObject:[dict objectForKey:@"rootId"]];
    }
}

- (void)CMCredentialRequest:(NSDictionary *)dict
{
    // Hide current alert to show the new one
    if ([self.presentedViewController isKindOfClass:[UIAlertController class]])
    {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    }

    NSString *serviceIdentifier = [dict objectForKey:@"service"];
    NSString *accountName = [SSKeychain accountsForService:serviceIdentifier].firstObject[kSSKeychainAccountKey];
    NSString *password = [SSKeychain passwordForService:serviceIdentifier account:accountName];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Authentication",nil)
                                                                   message:NSLocalizedString(@"Enter login/password\nLong press on server to change password if needed",nil)
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * action) {
                                                   UITextField *userField = alert.textFields[0];
                                                   UITextField *passField = alert.textFields[1];
                                                   [self.connectionManager setCredential:userField.text
                                                                                password:passField.text];

                                                   [self.connectionManager logout];
                                                   // Login
                                                   BOOL needToWaitLogin = NO;
                                                   needToWaitLogin = [self.connectionManager login];

                                                   // Get file list if possible
                                                   if (!needToWaitLogin)
                                                   {
                                                       [self.connectionManager listForPath:self.currentFolder];
                                                   }

                                                   [alert dismissViewControllerAnimated:YES completion:nil];
                                               }];

    UIAlertAction* save = [UIAlertAction actionWithTitle:NSLocalizedString(@"Save", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                     UITextField *userField = alert.textFields[0];
                                                     UITextField *passField = alert.textFields[1];

                                                     NSString *accountName = userField.text;
                                                     NSString *password = passField.text;
                                                     if (accountName.length)
                                                         [SSKeychain setPassword:password forService:serviceIdentifier account:accountName];
                                                     [self.connectionManager setCredential:userField.text
                                                                                  password:passField.text];

                                                     [self.connectionManager logout];
                                                     // Login
                                                     BOOL needToWaitLogin = NO;
                                                     needToWaitLogin = [self.connectionManager login];

                                                     // Get file list if possible
                                                     if (!needToWaitLogin)
                                                     {
                                                         [self.connectionManager listForPath:self.currentFolder];
                                                     }
                                                 }];

    UIAlertAction* delete;
    if (accountName.length || password.length)
    {
        delete = [UIAlertAction actionWithTitle:NSLocalizedString(@"Delete", nil)
                                          style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction * action) {
                                            [SSKeychain deletePasswordForService:serviceIdentifier account:accountName];
                                            [alert dismissViewControllerAnimated:YES completion:nil];
                                            [self.navigationController popToRootViewControllerAnimated:YES];
                                        }];
    }

    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       [alert dismissViewControllerAnimated:YES completion:nil];
                                                       [self.navigationController popViewControllerAnimated:YES];
                                                   }];

    [alert addAction:ok];
    [alert addAction:save];
    if (delete)
    {
        [alert addAction:delete];
    }
    [alert addAction:cancel];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"Username",nil);
        textField.text = accountName;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"Password",nil);
        textField.text = password;
        textField.secureTextEntry = YES;
    }];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)CMDownloadProgress:(NSDictionary *)dict
{
    if ([dict objectForKey:@"progress"])
    {
        float progress = [[dict objectForKey:@"progress"] floatValue];
        if (progress != 0)
        {
            [SVProgressHUD showProgress:progress];
        }
        if ([dict objectForKey:@"downloadedBytes"])
        {
            NSNumber *downloaded = [dict objectForKey:@"downloadedBytes"];
            NSNumber *totalSize = [dict objectForKey:@"totalBytes"];
            [SVProgressHUD showProgress:progress status:[NSString stringWithFormat:@"%@ of %@ done",[downloaded stringForNumberOfBytes],[totalSize stringForNumberOfBytes]]];
        }
    }
    else
    {
        NSNumber *downloaded = [dict objectForKey:@"downloadedBytes"];
        [SVProgressHUD showWithStatus:[NSString stringWithFormat:@"%@ done",[downloaded stringForNumberOfBytes]]];
    }
}

- (void)CMDownloadFinished:(NSDictionary *)dict
{
    [SVProgressHUD dismiss];

    if ([[dict objectForKey:@"success"] boolValue])
    {
        switch (self.downloadAction)
        {
            case DOWNLOAD_ACTION_SUBTITLE:
            {
                [self showVLCPlayerForFile:self.videoFile withSubtitles:self.dlFilePath];
                break;
            }
            case DOWNLOAD_ACTION_PREVIEW:
            {
#if 0
                FileItem *file = [[FileItem alloc] init];
                file.fullPath = self.dlFilePath;
                file.path = self.dlFilePath;
                file.name = self.sourceFileItem.name;
                file.type = self.sourceFileItem.type;
                file.isDir = NO;
                file.isCompressed = self.sourceFileItem.isCompressed;
                [self previewFile:file];
#endif
                break;
            }
            case DOWNLOAD_ACTION_DOWNLOAD:
            {
                // Nothing to do
                break;
            }
        }
    }
    else
    {
        switch (self.downloadAction)
        {
            case DOWNLOAD_ACTION_SUBTITLE:
            {
                [self showVLCPlayerForFile:self.videoFile withSubtitles:nil];
                break;
            }
            default:
            {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"File download",nil)
                                                                               message:NSLocalizedString([dict objectForKey:@"error"],nil)
                                                                        preferredStyle:UIAlertControllerStyleAlert];

                UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                                        style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * action) {
                                                                          [alert dismissViewControllerAnimated:YES completion:nil];
                                                                      }];
                [alert addAction:defaultAction];
                [self presentViewController:alert animated:YES completion:nil];
                break;
            }
        }
    }
}

- (void)CMDeleteProgress:(NSDictionary *)dict
{
    float progress = [[dict objectForKey:@"progress"] floatValue];
    if ((progress != 0) && ([dict objectForKey:@"info"]))
    {
        [SVProgressHUD showProgress:progress status:[dict objectForKey:@"info"]];
    }
    if (progress != 0)
    {
        [SVProgressHUD showProgress:progress];
    }
}

- (void)CMDeleteFinished:(NSDictionary *)dict
{
    [SVProgressHUD dismiss];

    if ([[dict objectForKey:@"success"] boolValue] == NO)
    {
        // Show error
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"File delete",nil)
                                                                       message:NSLocalizedString([dict objectForKey:@"error"],nil)
                                                                preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                                  [alert dismissViewControllerAnimated:YES completion:nil];
                                                                  // Update space information
                                                                  //                                                                [self.connectionManager spaceInfoAtPath:self.currentFolder];

                                                                  // Get file list
                                                                  [self.connectionManager listForPath:self.currentFolder];
                                                              }];
        [alert addAction:defaultAction];

        [self presentViewController:alert animated:YES completion:nil];
    }
    else
    {
        // Update space information
        //      [self.connectionManager spaceInfoAtPath:self.currentFolder];

        // If there is no file, go back to previous folder
        if (self.filesArray.count == 0)
        {
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}

- (void)CMConnectionError:(NSDictionary *)dict
{
    // We should hide HUD if any ...
    [SVProgressHUD dismiss];

    // Hide current alert to show the new one
    if ([self.presentedViewController isKindOfClass:[UIAlertController class]])
    {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Connection error",nil)
                                                                   message:NSLocalizedString([dict objectForKey:@"error"],nil)
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              [alert dismissViewControllerAnimated:YES completion:nil];
                                                          }];
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Memory management

- (void)dealloc
{
    // To fix "-[UIView release]: message sent to deallocated instance xxxxx"
    self.tableView.tableHeaderView = nil;
}

@end
