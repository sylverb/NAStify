//
//  FileBrowserViewController.m
//  NAStify-tvOS
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2015 CodeIsALie. All rights reserved.
//

#import <AVKit/AVKit.h>
#import "TVFileBrowserViewController.h"
#import "FileItem.h"

// File viewers
#import "TVCustomMoviePlayerViewController.h"
#import "VLCPlaybackController.h"
#import "VLCPlayerDisplayController.h"

#import "private.h"

@interface FileBrowserViewController (Private)
- (void)triggerReconnect;
- (BOOL)getSubtitleFileForMedia:(FileItem *)media;
@end

@interface FileBrowserViewController ()
{
    VLCMediaPlayer *_mediaplayer;
}
@end

@implementation FileBrowserViewController

- (id)init
{
    self = [super init];
    if (self)
    {
        self.isConnected = FALSE;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];

    if (!self.connectionManager)
    {
        self.connectionManager = [[ConnectionManager alloc] init];
        self.connectionManager.userAccount = self.userAccount;
    }

    // Setup tableView
    self.multipleSelectionTableView = [[UITableView alloc] initWithFrame:[[self view] bounds] style:UITableViewStylePlain];
	[self.multipleSelectionTableView setDelegate:self];
	[self.multipleSelectionTableView setDataSource:self];
    [self.view addSubview:self.multipleSelectionTableView];

    NSString *title = [[self.currentFolder.path componentsSeparatedByString:@"/"] lastObject];
    self.navigationItem.title = title;
    
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];

    self.filteredFilesArray = [[NSMutableArray alloc] init];
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
        [self.multipleSelectionTableView reloadData];
    }
    
    // Delete cached files if needed
    NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
    NSString *cacheFolder = [containerURL.path stringByAppendingString:@"/Cache/"];
    
    NSDirectoryEnumerator* en = [[NSFileManager defaultManager] enumeratorAtPath:cacheFolder];
    
    NSString* file;
    while (file = [en nextObject])
    {
        [[NSFileManager defaultManager] removeItemAtPath:[cacheFolder stringByAppendingPathComponent:file] error:NULL];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    self.connectionManager.delegate = self;
    
	if ([self.currentFolder.path isEqualToString:@"/"])
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
                [self.connectionManager spaceInfoAtPath:self.currentFolder];
            }
        }
        else if (self.userAccount.serverType == SERVER_TYPE_LOCAL)
        {
            // Get file list
            [self.connectionManager listForPath:self.currentFolder];
            [self.connectionManager spaceInfoAtPath:self.currentFolder];
        }
	}
    else if ([self.filesArray count] == 0)
    {
		// Get file list
		[self.connectionManager listForPath:self.currentFolder];
        [self.connectionManager spaceInfoAtPath:self.currentFolder];
	}
    else if (self.userAccount.serverType == SERVER_TYPE_LOCAL)
    {
		// Get file list (we are with local files, it costs nothing to reload here)
		[self.connectionManager listForPath:self.currentFolder];
        [self.connectionManager spaceInfoAtPath:self.currentFolder];
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
        if ([[file.name stringByDeletingPathExtension] isEqualToString:urlTemp])
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
    tableView = self.multipleSelectionTableView;
    
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
    return [self.filesArray count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *FileBrowserCellIdentifier = @"FileBrowserCell";
    
    FileItem *fileItem = nil;
    fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);
    
    FileBrowserCell *fileBrowserCell = (FileBrowserCell *)[tableView dequeueReusableCellWithIdentifier:FileBrowserCellIdentifier];
    if (fileBrowserCell == nil)
    {
        fileBrowserCell = [[FileBrowserCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                 reuseIdentifier:FileBrowserCellIdentifier];
    }
#if 0
    // Remove long tap gesture recognizer if present
    NSArray *gestureList = [fileBrowserCell gestureRecognizers];
    for (id gesture in gestureList)
    {
        if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]])
        {
            [fileBrowserCell removeGestureRecognizer:gesture];
            break;
        }
    }
    
    // Long tap recognizer
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressAction:)];
    [fileBrowserCell addGestureRecognizer:longPressRecognizer];
#endif
    
    // Configure the cell...
    [fileBrowserCell setFileItem:fileItem
                    withDelegate:self
                          andTag:TAG_TEXTFIELD_FILENAME];
    
    return fileBrowserCell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL result = NO;
    if (tableView.isEditing)
    {
        result = YES;
    }
    else
    {
        NSMutableArray *sourceArray = nil;
        sourceArray = self.filesArray;

        FileItem *fileItem = (FileItem *)([sourceArray objectAtIndex:indexPath.row]);
        // Check if the server supports deleting this kind of file
        if (((fileItem.isDir)&&(ServerSupportsFeature(FolderDelete))) ||
            ((!fileItem.isDir)&&(ServerSupportsFeature(FileDelete))))
        {
            result = fileItem.writeAccess;
        }
    }
    return result;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    {
        FileItem *fileItem = nil;
        fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);

        // Show file if possible
        if (![self openFile:fileItem])
        {
            // For not handled types, show action menu
//            [self showActionMenuForItemAtIndexPath:indexPath];
        }
        // deselect the cell
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (BOOL)openFile:(FileItem *)fileItem
{
    BOOL itemHandled = NO;
    switch ([fileItem fileType])
    {
        case FILETYPE_FOLDER:
        {
            itemHandled = YES;
            FileBrowserViewController *fileBrowserViewController = [[FileBrowserViewController alloc] init];
            fileBrowserViewController.isConnected = TRUE;
            fileBrowserViewController.currentFolder = fileItem;
            fileBrowserViewController.userAccount = self.userAccount; // Not needed, may be useful for future needs
            fileBrowserViewController.connectionManager = self.connectionManager;
            [self.navigationController pushViewController:fileBrowserViewController animated:YES];
            break;
        }
        case FILETYPE_VLC_VIDEO:
        {
            if (ServerSupportsFeature(VLCPlayer))
            {
                itemHandled = YES;
                self.videoNetworkConnection = [self.connectionManager urlForVideo:fileItem];

                if (![self getSubtitleFileForMedia:fileItem])
                {
                    [VLCPlayerDisplayController sharedInstance].displayMode = VLCPlayerDisplayControllerDisplayModeFullscreen;
                    
                    VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
                    vpc.url = self.videoNetworkConnection.url;
                    [vpc playURL:[self.connectionManager urlForVideo:fileItem].url subtitlesFilePath:nil];
                }
            }
            break;
        }
        case FILETYPE_QT_VIDEO:
        {
            if (([self.connectionManager pluginRespondsToSelector:@selector(urlForFile:)]) ||
                ([self.connectionManager pluginRespondsToSelector:@selector(urlForVideo:)]))
            {
                NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
                self.videoNetworkConnection = [self.connectionManager urlForVideo:fileItem];
                
                {
                    if ((([[defaults objectForKey:kNASTifySettingInternalPlayer] integerValue] == kNASTifySettingInternalPlayerTypeVLCOnly) && (ServerSupportsFeature(VLCPlayer))))
                    {
                        // Use VLC player
                        itemHandled = YES;
                        if (![self getSubtitleFileForMedia:fileItem])
                        {
                            [VLCPlayerDisplayController sharedInstance].displayMode = VLCPlayerDisplayControllerDisplayModeFullscreen;
                            
                            VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
                            [vpc playURL:[self.connectionManager urlForVideo:fileItem].url subtitlesFilePath:nil];
                        }
                    }
                    else if (ServerSupportsFeature(QTPlayer))
                    {
                        itemHandled = YES;
                        // Internal player can handle this media
                        CustomMoviePlayerViewController *mp = [[CustomMoviePlayerViewController alloc] init];
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
                            [VLCPlayerDisplayController sharedInstance].displayMode = VLCPlayerDisplayControllerDisplayModeFullscreen;
                            
                            VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
                            [vpc playURL:self.videoNetworkConnection.url subtitlesFilePath:nil];
                        }
                    }
                }
            }
            break;
        }
        case FILETYPE_UNKNOWN:
        default:
        {
            // Nothing to do
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
        [self.connectionManager spaceInfoAtPath:self.currentFolder];
    }
    else
    {
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
#if 0
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        [hud hide:YES];
#endif
    }
}

- (void)CMRequestOTP:(NSNotification *)notification
{
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
        if ([[dict objectForKey:@"success"] boolValue])
        {
            self.isConnected = TRUE;

            NSArray *filesList = [dict objectForKey:@"filesList"];
            
            self.filesArray = [[NSMutableArray alloc] init];
            
            for (NSDictionary *element in filesList)
            {
                FileItem *fileItem = [[FileItem alloc] init];
                fileItem.name = [element objectForKey:@"filename"];
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
            
            // Sort files array
            [self.filesArray sortFileItemArrayWithOrder:self.sortingType];
            
            // Refresh tableView
            [self.multipleSelectionTableView reloadData];

//            [self.multipleSelectionTableView performSelectorOnMainThread:@selector(reloadData)
//                                                              withObject:nil
//                                                           waitUntilDone:NO];
        }
        else
        {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Browse",nil)
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

- (void)CMSpaceInfo:(NSDictionary *)dict
{
    if ([[dict objectForKey:@"success"] boolValue])
    {
        if (self.spaceInfo == nil)
        {
            CGRect tableViewFrame = self.multipleSelectionTableView.frame;
            tableViewFrame.size.height -= 30;
            [self.multipleSelectionTableView setFrame:tableViewFrame];
            
            self.spaceInfo = [[UILabel alloc] initWithFrame:CGRectMake(0,
                                                                       self.multipleSelectionTableView.bounds.size.height,
                                                                       self.view.bounds.size.width,
                                                                       30)];
            self.spaceInfo.textAlignment = NSTextAlignmentCenter;
            self.spaceInfo.textColor = [UIColor whiteColor];
            self.spaceInfo.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
            self.spaceInfo.backgroundColor = [UIColor colorWithRed:0.0
                                                             green:0.0
                                                              blue:0.0
                                                             alpha:0.65];
            self.spaceInfo.font = [UIFont fontWithName:@"Helvetica" size:17];
            [self.view addSubview:self.spaceInfo];
        }
        self.spaceInfo.text = [NSString stringWithFormat:@"Free/Total : %@ / %@",
                               [[dict objectForKey:@"freespace"] stringForNumberOfBytes],
                               [[dict objectForKey:@"totalspace"] stringForNumberOfBytes]];
    }
}

- (void)CMCredentialRequest:(NSDictionary *)dict
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Authentication",nil)
                                                                   message:NSLocalizedString(@"Enter login/password",nil)
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
                                                       [self.connectionManager spaceInfoAtPath:self.currentFolder];
                                                   }
                                                   
                                                   [alert dismissViewControllerAnimated:YES completion:nil];
                                               }];
    
    UIAlertAction* cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       [alert dismissViewControllerAnimated:YES completion:nil];
                                                   }];
    
    [alert addAction:ok];
    [alert addAction:cancel];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Username";
        if ([dict objectForKey:@"user"])
        {
            textField.text = [dict objectForKey:@"user"];
        }
        
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Password";
        textField.secureTextEntry = YES;
    }];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)CMDownloadProgress:(NSDictionary *)dict
{
#if 0
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    if ([dict objectForKey:@"progress"])
    {
        float progress = [[dict objectForKey:@"progress"] floatValue];
        if (progress != 0)
        {
            hud.mode = MBProgressHUDModeAnnularDeterminate;
            hud.progress = progress;
        }
        if ([dict objectForKey:@"downloadedBytes"])
        {
            NSNumber *downloaded = [dict objectForKey:@"downloadedBytes"];
            NSNumber *totalSize = [dict objectForKey:@"totalBytes"];
            hud.detailsLabelText = [NSString stringWithFormat:@"%@ of %@ done",[downloaded stringForNumberOfBytes],[totalSize stringForNumberOfBytes]];
        }
    }
    else
    {
        NSNumber *downloaded = [dict objectForKey:@"downloadedBytes"];
        hud.detailsLabelText = [NSString stringWithFormat:@"%@ done",[downloaded stringForNumberOfBytes]];
    }
#endif
}

- (void)CMDownloadFinished:(NSDictionary *)dict
{
    if ([[dict objectForKey:@"success"] boolValue])
    {
        switch (self.downloadAction)
        {
            case DOWNLOAD_ACTION_SUBTITLE:
            {
                [VLCPlayerDisplayController sharedInstance].displayMode = VLCPlayerDisplayControllerDisplayModeFullscreen;
                
                VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
                [vpc playURL:self.videoNetworkConnection.url subtitlesFilePath:self.dlFilePath];
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
        if (self.videoNetworkConnection)
        {
        }
    }
    else
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
    }
    
#if 0
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
#endif
}

- (void)CMConnectionError:(NSDictionary *)dict
{
#if 0
    // We should hide HUD if any ...
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
#endif
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
    self.multipleSelectionTableView.tableHeaderView = nil;
}

@end
