//
//  FileBrowserViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//
//  TODO : Add more file viewers (epub, ...)
//  TODO : add something to explain to the user how to use the application (long tap on file for options)
//  TODO : in filtered view, if selecting/deselecting a folder, select/unselect content of the folder (think also to remove unneeded element for copy/move/archive)
//  TODO : create a download/upload queue manager which will handle all requested downloads
//  TODO : file download should show a folder browser to select where to store file

#import "FileBrowserViewController.h"
#import "CustomNavigationController.h"
#import "CustomTabBarController.h"
#import "FileItem.h"

#import "ExtractViewController.h"
#import "CompressViewController.h"
#import "SortItemsViewController.h"

// File viewers
#import "CustomMoviePlayerViewController.h"
#import "VLCMovieViewController.h"

// Settings
#import "SettingsViewController.h"

#import "private.h"

@interface FileBrowserViewController (Private)
- (void)longPressAction:(UILongPressGestureRecognizer*)longPressRecognizer;
- (void)toggleEditButton;
- (void)updateActionBar;
- (void)updateBarButtons;
- (void)showActionMenuForItemAtIndexPath:(NSIndexPath *)indexpath;
- (void)updateFilteredResults;
- (void)triggerReconnect;
- (BOOL)selectedFilesCanBeExtracted;
- (BOOL)showEditButton;
- (BOOL)getSubtitleFileForMedia:(FileItem *)media;
- (BOOL)previewFile:(FileItem *)fileItem;
- (BOOL)openFile:(FileItem *)fileItem;
@end

/* Alert Tags */
#define TAG_ALERT_CREATE_FOLDER 0
#define TAG_ALERT_OTP           1
#define TAG_ALERT_DO_NOTHING    2
#define TAG_ALERT_DISCONNECT    3
#define TAG_ALERT_DELETE_FILES  4

/* HUD Tags */
#define TAG_HUD_DOWNLOAD    1
#define TAG_HUD_COPY        2
#define TAG_HUD_MOVE        3
#define TAG_HUD_EXTRACT     4
#define TAG_HUD_COMPRESS    5
#define TAG_HUD_DELETE      6
#define TAG_HUD_SEARCH      7
#define TAG_HUD_UPLOAD      8
#define TAG_HUD_LOGOUT      9

#define TABLE_ROW_HEIGHT    50.0f

#define SEARCH_SCOPE_FOLDER 0
#define SEARCH_SCOPE_RECURSIVE 1

@interface FileBrowserViewController ()

@end

@implementation FileBrowserViewController

@synthesize searchDisplayController;

- (id)init
{
    self = [super init];
    if (self)
    {
        self.selectedIndexes = [[NSMutableIndexSet alloc] init];
        self.isConnected = FALSE;
        self.interstitialPresentationPolicy = ADInterstitialPresentationPolicyManual;

        _gcController = [GoogleCastController sharedGCController];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //Create chromecast button
    _btnImage = [UIImage imageNamed:@"icon-cast-identified.png"];
    _btnImageSelected = [UIImage imageNamed:@"icon-cast-connected.png"];
    
    _chromecastButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [_chromecastButton addTarget:self
                          action:@selector(chooseDevice:)
                forControlEvents:UIControlEventTouchDown];
    _chromecastButton.frame = CGRectMake(0, 0, _btnImage.size.width, _btnImage.size.height);
    [_chromecastButton setImage:nil forState:UIControlStateNormal];
    _chromecastButton.hidden = NO;
    
    //
    
    if (!self.connectionManager)
    {
        self.connectionManager = [[ConnectionManager alloc] init];
        self.connectionManager.userAccount = self.userAccount;
    }

    self.edgesForExtendedLayout = UIRectEdgeNone;
    [self setAutomaticallyAdjustsScrollViewInsets:NO];
    
    // Setup tableView
    self.multipleSelectionTableView = [[UITableView alloc] initWithFrame:[[self view] bounds] style:UITableViewStylePlain];
	[self.multipleSelectionTableView setDelegate:self];
	[self.multipleSelectionTableView setDataSource:self];
	[self.multipleSelectionTableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    self.multipleSelectionTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.multipleSelectionTableView.rowHeight = TABLE_ROW_HEIGHT;

    // Setup search
    CGRect f = [[self view] bounds];
    
    CGRect searchBarFrame = CGRectMake(0.0f, 0.0f, f.size.width, 50.0f);
    self.searchBar = [[UISearchBar alloc] initWithFrame:searchBarFrame];
    self.searchBar.delegate = self;
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.barStyle = UIBarStyleBlack;
    self.searchBar.placeholder = NSLocalizedString(@"Search",nil);

    self.multipleSelectionTableView.tableHeaderView = self.searchBar;
    [self.multipleSelectionTableView setContentOffset:CGPointMake(0,searchBarFrame.size.height)];
    
    [self.view addSubview:self.multipleSelectionTableView];
    
    self.searchDisplayController = [[CustomSearchDisplayController alloc] initWithSearchBar:self.searchBar
                                                                    contentsController:self];
    
	[self.searchDisplayController setDelegate:self];
	[self.searchDisplayController setSearchResultsDataSource:self];
    [self.searchDisplayController setSearchResultsDelegate:self];

    NSString *title = [[self.currentFolder.path componentsSeparatedByString:@"/"] lastObject];
	if ([title length] == 0)
    {
		title = @"/";
        [self.navigationItem setHidesBackButton:YES animated:NO];
        if (self.userAccount.serverType != SERVER_TYPE_LOCAL)
        {
            self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                                                  target:self
                                                                                                  action:@selector(confirmDisconnect)];
        }
        [super viewDidLoad];
	}
    
    self.navigationItem.title = title;
    
    [self updateBarButtons];
    
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [self.navigationController.toolbar setTintColor:[UIColor blackColor]];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(dropViewDidBeginRefreshing:) forControlEvents:UIControlEventValueChanged];
    [self.multipleSelectionTableView addSubview:self.refreshControl];
    
    self.filteredFilesArray = [[NSMutableArray alloc] init];
}

- (void)updateBarButtons
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    NSMutableArray *buttonItems = [NSMutableArray array];
    
    if ([self showEditButton])
    {
        [buttonItems addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                             target:self
                                                                             action:@selector(toggleEditButton)]];
    }
    
    [buttonItems addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                         target:self
                                                                         action:@selector(actionButton:)]];
    
    [buttonItems addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemOrganize
                                                                         target:self
                                                                         action:@selector(sortButton:)]];
    
    if ([[defaults objectForKey:kNASTifySettingBrowserShowGCast] boolValue] &&
        ServerSupportsFeature(GoogleCast) &&
        (_gcController.deviceScanner.devices.count != 0))
    {
        //Show cast button
        [_chromecastButton setImage:_btnImage forState:UIControlStateNormal];
        
        if (_gcController.deviceManager && _gcController.deviceManager.isConnected)
        {
            //Show cast button in enabled state
            [_chromecastButton setTintColor:[UIColor blueColor]];
        }
        else
        {
            //Show cast button in disabled state
            [_chromecastButton setTintColor:[UIColor grayColor]];
        }
        
        [buttonItems addObject:[[UIBarButtonItem alloc] initWithCustomView:_chromecastButton]];
    }
    
    self.navigationItem.rightBarButtonItems = buttonItems ;

}

- (void)dropViewDidBeginRefreshing:(UIRefreshControl *)refreshControl
{
    [self.connectionManager listForPath:self.currentFolder];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(triggerReconnect)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    if (ServerSupportsFeature(Search))
    {
        [self.searchBar setScopeButtonTitles:[NSArray arrayWithObjects:
                                              NSLocalizedString(@"Folder",nil),
                                              NSLocalizedString(@"Recursive",nil),
                                              nil]];
    }
    
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
    
    // Show tab bar if it was not visible
    [(CustomTabBarController *)self.tabBarController setTabBarHidden:NO withAnimation:YES];
    
    _gcController.delegate = self;

    // Update buttons
    [self updateBarButtons];
    
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
                
                // Request ad
                [self requestAd];

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
    
    // Hide toolbar if needed
    if ([self activeTableView].isEditing)
    {
        [self toggleEditButton];
    }
    
    // Remove popover if needed
    if (self.sortPopoverController.isPopoverVisible)
    {
        [self.sortPopoverController dismissPopoverAnimated:YES];
        self.sortPopoverController = nil;
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


#pragma mark -
#pragma mark Disconnection handling

- (void)confirmDisconnect
{
    if ((self.isConnected) && ([self.connectionManager needLogout]))
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Warning",nil)
                                                        message:NSLocalizedString(@"Are you sure you want to disconnect from server ?",nil)
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel",nil)
                                              otherButtonTitles:NSLocalizedString(@"Yes",nil), nil];
        alert.tag = TAG_ALERT_DISCONNECT;
        
        [alert show];
    }
    else
    {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - MoveFileViewControllerDelegate

- (void)backFromModalView:(BOOL)refreshList
{
    self.connectionManager.delegate = self;
    // On iPad, viewWillAppear is not called if modalPresentationStyle = UIModalPresentationFormSheet
    // as view didn't disappear
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        if ((self.userAccount.serverType == SERVER_TYPE_LOCAL) ||
            (refreshList))
        {
            // Get file list (we are with local files, it costs nothing to reload here)
            [self.connectionManager listForPath:self.currentFolder];
            [self.connectionManager spaceInfoAtPath:self.currentFolder];
        }
    }
    else if (refreshList)
    {
        // Get file list as latest operation may have changed folder content
        [self.connectionManager listForPath:self.currentFolder];
        [self.connectionManager spaceInfoAtPath:self.currentFolder];
    }
}

#pragma mark - UploadBrowserViewControllerDelegate

- (void)uploadFile:(FileItem *)file
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                              animated:YES];
    if (ServerSupportsFeature(UploadCancel))
    {
        hud.allowsCancelation = YES;
        hud.tag = TAG_HUD_UPLOAD;
    }
    hud.delegate = self;
    hud.labelText = NSLocalizedString(@"Uploading", nil);
    
    [self.connectionManager uploadLocalFile:file
                                     toPath:self.currentFolder
                                  overwrite:YES
                                serverFiles:self.filesArray];
}

#pragma mark - button actions

- (void)updateActionBar
{
    // Update labels for count
    if ([self.selectedIndexes count] == 0)
    {
        self.deleteFilesButtonItem.title = NSLocalizedString(@"Delete",nil);
        [self.deleteFilesButtonItem setEnabled:NO];
        self.moveCopyFilesButtonItem.title = NSLocalizedString(@"Copy/Move",nil);
        [self.moveCopyFilesButtonItem setEnabled:NO];
        self.compressFilesButtonItem.title = NSLocalizedString(@"Compress",nil);
        [self.compressFilesButtonItem setEnabled:NO];
        self.extractFilesButtonItem.title = NSLocalizedString(@"Extract",nil);
        [self.extractFilesButtonItem setEnabled:NO];
        self.shareFilesButtonItem.title = NSLocalizedString(@"Share",nil);
        [self.shareFilesButtonItem setEnabled:NO];
    }
    else
    {
        self.deleteFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Delete (%d)",nil),[self.selectedIndexes count]];
        [self.deleteFilesButtonItem setEnabled:YES];
        self.moveCopyFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Copy/Move (%d)",nil),[self.selectedIndexes count]];
        [self.moveCopyFilesButtonItem setEnabled:YES];
        self.compressFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Compress (%d)",nil),[self.selectedIndexes count]];
        [self.compressFilesButtonItem setEnabled:YES];
        if ((ServerSupportsFeature(Extract)) && ([self selectedFilesCanBeExtracted]))
        {
            if (!(ServerSupportsFeature(ExtractMultiple)) && ([self.selectedIndexes count] > 1))
            {
                self.extractFilesButtonItem.title = NSLocalizedString(@"Extract",nil);
                [self.extractFilesButtonItem setEnabled:NO];
            }
            else
            {
                self.extractFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Extract (%d)",nil),[self.selectedIndexes count]];
                [self.extractFilesButtonItem setEnabled:YES];
            }
        }
        else
        {
            self.extractFilesButtonItem.title = NSLocalizedString(@"Extract",nil);
            [self.extractFilesButtonItem setEnabled:NO];
        }
        if ((ServerSupportsFeature(FileShare)) || (ServerSupportsFeature(FolderShare)))
        {
            self.shareFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Share (%d)",nil),[self.selectedIndexes count]];
            [self.shareFilesButtonItem setEnabled:YES];
        }

    }
}

- (BOOL)showEditButton
{
    if ((ServerSupportsFeature(FileDelete))   ||
        (ServerSupportsFeature(FolderDelete)) ||
        (ServerSupportsFeature(FileMove))     ||
        (ServerSupportsFeature(FolderMove))   ||
        (ServerSupportsFeature(FileCopy))     ||
        (ServerSupportsFeature(FolderCopy))   ||
        (ServerSupportsFeature(Compress))     ||
        (ServerSupportsFeature(Extract)))
    {
        return YES;
    }
    
    return NO;
}

- (void)toggleEditButton
{
    if (self.sortPopoverController.isPopoverVisible)
    {
        [self.sortPopoverController dismissPopoverAnimated:YES];
        self.sortPopoverController = nil;
    }

    UITableView *tableView = [self activeTableView];
    if (self.searchDisplayController.active)
    {
        [self.searchBar resignFirstResponder];
    }

    if (tableView.isEditing)
    {
        [tableView setAllowsMultipleSelectionDuringEditing:NO];
        [tableView setEditing:NO animated:YES];
        
        [self updateBarButtons];
        
        [self.selectedIndexes removeAllIndexes];
        [self.navigationController setToolbarHidden:YES animated:YES];
        
        // Enable pull to refresh
        [self.multipleSelectionTableView addSubview:self.refreshControl];
        
        /* Restore long tap handling (was removed when entered edit mode) */
        NSInteger rows = [tableView numberOfRowsInSection:0];
        NSInteger index;
        for (index = 0; index < rows; index++)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            UITableViewCell *oneCell = [tableView cellForRowAtIndexPath:indexPath];
            
            // Long tap recognizer
            UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                              action:@selector(longPressAction:)];
            [oneCell addGestureRecognizer:longPressRecognizer];
        }
        
        // Enable pressing on back button
        if ([self.currentFolder.path isEqualToString:@"/"])
        {
            if (self.userAccount.serverType != SERVER_TYPE_LOCAL)
            {
                self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                                                      target:self
                                                                                                      action:@selector(confirmDisconnect)];
            }
        }
        else
        {
            [self.navigationItem setHidesBackButton:NO animated:YES];
        }
    }
    else
    {
        // Disable pull to refresh
        [self.refreshControl endRefreshing];
        [self.refreshControl removeFromSuperview];

        // Disable pressing back button
        if ([self.currentFolder.path isEqualToString:@"/"])
        {
            if (self.userAccount)
            {
                self.navigationItem.leftBarButtonItem = nil;
            }
        }
        else
        {
            [self.navigationItem setHidesBackButton:YES animated:YES];
        }

        // Enter edit mode
        [tableView setAllowsMultipleSelectionDuringEditing:YES];
        [tableView setEditing:YES animated:YES];

        /* Remove long tap handling (need to be restored at the end of renaming) */
        NSInteger rows = [tableView numberOfRowsInSection:0];
        NSInteger index;
        for (index = 0; index < rows; index++)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            UITableViewCell *oneCell = [tableView cellForRowAtIndexPath:indexPath];
            
            NSArray *gestureList = [oneCell gestureRecognizers];
            for (id gesture in gestureList)
            {
                if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]])
                {
                    [oneCell removeGestureRecognizer:gesture];
                    break;
                }
            }
        }
        
        // Setup toolbar
        UIBarButtonItem *cancelEditButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                        target:self
                                                                                        action:@selector(toggleEditButton)];
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObject:cancelEditButtonItem];
        
        NSMutableArray *buttons = [NSMutableArray arrayWithCapacity:5];
        UIBarButtonItem *flexibleSpaceButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                                 target:nil
                                                                                                 action:nil];
        
        if ((ServerSupportsFeature(FileDelete)) ||
            (ServerSupportsFeature(FolderDelete)))
        {
            [buttons addObject:flexibleSpaceButtonItem];
            
            if (self.deleteFilesButtonItem)
            {
                self.deleteFilesButtonItem.title = NSLocalizedString(@"Delete",nil);
            }
            else
            {
                self.deleteFilesButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Delete",nil)
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(deleteSelectedFiles:)];
                [self.deleteFilesButtonItem setTintColor:[UIColor colorWithRed:255.0/255.0
                                                                         green:55.0/255.0
                                                                          blue:55.0/255.0
                                                                         alpha:1.0]];
            }
            [buttons addObject:self.deleteFilesButtonItem];
        }
        
        if ((ServerSupportsFeature(FileMove)) ||
            (ServerSupportsFeature(FolderMove)) ||
            (ServerSupportsFeature(FileCopy)) ||
            (ServerSupportsFeature(FolderCopy)))
        {
            [buttons addObject:flexibleSpaceButtonItem];
            [self.deleteFilesButtonItem setEnabled:NO];
            
            if (self.moveCopyFilesButtonItem)
            {
                self.moveCopyFilesButtonItem.title = NSLocalizedString(@"Copy/Move",nil);
            }
            else
            {
                self.moveCopyFilesButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Copy/Move",nil)
                                                                                style:UIBarButtonItemStylePlain
                                                                               target:self
                                                                               action:@selector(copyMoveSelectedFiles:)];
            }
            [self.moveCopyFilesButtonItem setEnabled:NO];
            [buttons addObject:self.moveCopyFilesButtonItem];
        }
        
        if (ServerSupportsFeature(Compress))
        {
            [buttons addObject:flexibleSpaceButtonItem];
            if (self.compressFilesButtonItem)
            {
                self.compressFilesButtonItem.title = NSLocalizedString(@"Compress",nil);
            }
            else
            {
                self.compressFilesButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Compress",nil)
                                                                                style:UIBarButtonItemStylePlain
                                                                               target:self
                                                                               action:@selector(compressSelectedFiles:)];
            }
            [self.compressFilesButtonItem setEnabled:NO];
            [buttons addObject:self.compressFilesButtonItem];
        }

        if (ServerSupportsFeature(Extract))
        {
            [buttons addObject:flexibleSpaceButtonItem];
            if (self.extractFilesButtonItem)
            {
                self.extractFilesButtonItem.title = NSLocalizedString(@"Extract",nil);
            }
            else
            {
                self.extractFilesButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Extract",nil)
                                                                                style:UIBarButtonItemStylePlain
                                                                               target:self
                                                                               action:@selector(extractSelectedFiles:)];
            }
            [self.extractFilesButtonItem setEnabled:NO];
            [buttons addObject:self.extractFilesButtonItem];
        }

        if ((ServerSupportsFeature(FileShare)) || (ServerSupportsFeature(FolderShare)))
        {
            [buttons addObject:flexibleSpaceButtonItem];
            if (self.shareFilesButtonItem)
            {
                self.shareFilesButtonItem.title = NSLocalizedString(@"Share",nil);
            }
            else
            {
                self.shareFilesButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Share",nil)
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(shareSelectedFiles:)];
            }
            [self.shareFilesButtonItem setEnabled:NO];
            [buttons addObject:self.shareFilesButtonItem];
        }

        [buttons addObject:flexibleSpaceButtonItem];
        if (self.invertSelectionButtonItem == nil)
        {
            self.invertSelectionButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Invert",nil)
                                                                         style:UIBarButtonItemStylePlain
                                                                        target:self
                                                                        action:@selector(invertSelectionButton:)];
        }
        [buttons addObject:self.invertSelectionButtonItem];

        [buttons addObject:flexibleSpaceButtonItem];
        
        [self setToolbarItems:buttons];
        [self.navigationController setToolbarHidden:NO animated:YES];
    }
}

- (void)deleteSelectedFiles:(UIBarButtonItem*)sender
{
    if ([self.selectedIndexes count] == 0)
    {
        return;
    }
    
    NSString *message = nil;
    if ([self.selectedIndexes count] == 1)
    {
        NSUInteger index = [self.selectedIndexes firstIndex];
        NSMutableArray *sourceArray = nil;
        if (self.searchDisplayController.active)
        {
            sourceArray = self.filteredFilesArray;
        }
        else
        {
            sourceArray = self.filesArray;
        }

        FileItem *file = (FileItem *)([sourceArray objectAtIndex:index]);
        message = [NSString stringWithFormat:NSLocalizedString(@"delete %@ ?",nil),file.name];
    }
    else
    {
        message = [NSString stringWithFormat:NSLocalizedString(@"delete %d files ?",nil),[self.selectedIndexes count]];
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Delete files",nil)
                                                    message:message
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel",nil)
                                          otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
    alert.tag = TAG_ALERT_DELETE_FILES;
    [alert show];
}

- (void)copyMoveSelectedFiles:(UIBarButtonItem*)sender
{
    if ([self.selectedIndexes count] == 0)
    {
        return;
    }
    
    NSMutableArray *sourceArray = nil;
    if (self.searchDisplayController.active)
    {
        sourceArray = self.filteredFilesArray;
    }
    else
    {
        sourceArray = self.filesArray;
    }
    
    NSMutableArray *fileItems = [NSMutableArray array];
    NSUInteger current_index = [self.selectedIndexes firstIndex];
    while (current_index != NSNotFound)
    {
        FileItem *fileItem = (FileItem *)([sourceArray objectAtIndex:current_index]);
        [fileItems addObject:fileItem];
        
        current_index = [self.selectedIndexes indexGreaterThanIndex: current_index];
    }
    
    if ([self activeTableView].isEditing)
    {
        [self toggleEditButton];
    }
    else
    {
        [self.selectedIndexes removeAllIndexes];
    }
    
    NSMutableArray *pathArray;
    if ([self.currentFolder.path isEqual:@"/"])
    {
        pathArray = [NSMutableArray arrayWithObject:@""];
    }
    else
    {
        pathArray = [NSMutableArray arrayWithArray:[self.currentFolder.path componentsSeparatedByString:@"/"]];
    }
    
    NSMutableArray *fullPathArray;
    if ([self.currentFolder.fullPath isEqual:@"/"])
    {
        fullPathArray = [NSMutableArray arrayWithObject:@""];
    }
    else
    {
        fullPathArray = [NSMutableArray arrayWithArray:[self.currentFolder.fullPath componentsSeparatedByString:@"/"]];
    }
    
    NSMutableArray *objectIds = nil;
    if (self.currentFolder.objectIds != nil)
    {
        objectIds = [NSMutableArray arrayWithArray:self.currentFolder.objectIds];
    }
    
    
    NSMutableArray *folderItems = [NSMutableArray array];
    while (pathArray.count > 0)
    {
        FileItem *folder = [[FileItem alloc] init];
        folder.isDir = YES;
        if (pathArray.count == 1)
        {
            folder.path = @"/";
        }
        else
        {
            folder.path = [pathArray componentsJoinedByString:@"/"];
        }
        folder.shortPath = folder.path;
        if (fullPathArray.count == 1)
        {
            folder.fullPath = @"/";
        }
        else
        {
            folder.fullPath = [fullPathArray componentsJoinedByString:@"/"];
        }
        if ((objectIds != nil) && (objectIds.count > 0))
        {
            folder.objectIds = [NSArray arrayWithArray:objectIds];
            [objectIds removeLastObject];
        }
        [folderItems insertObject:folder atIndex:0];
        
        [pathArray removeLastObject];
        [fullPathArray removeLastObject];
    }
    
    // Push all views
    
    // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
    // even with UIModalPresentationFormSheet (not the default behavior)
    CustomNavigationController *moveNavController = [[CustomNavigationController alloc] init];
    moveNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    for (FileItem *folder in folderItems)
    {
        MoveFileViewController *moveFileViewController = [[MoveFileViewController alloc] init];
        moveFileViewController.currentFolder = folder;
        moveFileViewController.filesToMove = fileItems;
        moveFileViewController.title = folder.path;
        moveFileViewController.delegate = self;
        moveFileViewController.connectionManager = self.connectionManager;
        [moveNavController pushViewController:moveFileViewController animated:NO];
    }
    [self.navigationController presentViewController:moveNavController
                                            animated:YES
                                          completion:nil];
}

- (void)compressSelectedFiles:(UIBarButtonItem*)sender
{
    if ([self.selectedIndexes count] == 0)
    {
        return;
    }
    
    NSMutableArray *sourceArray = nil;
    if (self.searchDisplayController.active)
    {
        sourceArray = self.filteredFilesArray;
    }
    else
    {
        sourceArray = self.filesArray;
    }

    NSMutableArray *fileItems = [NSMutableArray array];
    NSUInteger current_index = [self.selectedIndexes firstIndex];
    while (current_index != NSNotFound)
    {
        FileItem *fileItem = (FileItem *)([sourceArray objectAtIndex:current_index]);
        [fileItems addObject:fileItem];
        
        current_index = [self.selectedIndexes indexGreaterThanIndex: current_index];
    }

    if ([self activeTableView].isEditing)
    {
        [self toggleEditButton];
    }
    else
    {
        [self.selectedIndexes removeAllIndexes];
    }

    NSString *archiveName = nil;
    if ([fileItems count] == 1)
    {
        archiveName = ((FileItem *)[fileItems objectAtIndex:0]).name;
    }
    else
    {
        if ([self.currentFolder.path isEqualToString:@"/"])
        {
            archiveName = @"archive";
        }
        else
        {
            archiveName = [[self.currentFolder.path componentsSeparatedByString:@"/"] lastObject];
        }
    }
    // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
    // even with UIModalPresentationFormSheet (not the default behavior)
    CompressViewController *compressViewController = [[CompressViewController alloc] init];
    compressViewController.connectionManager = self.connectionManager;
    compressViewController.files = fileItems;
    compressViewController.atPath = self.currentFolder.path;
    compressViewController.destFolder = self.currentFolder;
    compressViewController.destArchiveName = archiveName;
    compressViewController.delegate = self;
    CustomNavigationController *extractNavController = [[CustomNavigationController alloc] initWithRootViewController:compressViewController];
    extractNavController.modalPresentationStyle = UIModalPresentationFormSheet;

    [self.navigationController presentViewController:extractNavController
                                            animated:YES
                                          completion:nil];
}

- (void)extractSelectedFiles:(UIBarButtonItem*)sender
{
    if ([self.selectedIndexes count] == 0)
    {
        return;
    }
    
    NSMutableArray *sourceArray = nil;
    if (self.searchDisplayController.active)
    {
        sourceArray = self.filteredFilesArray;
    }
    else
    {
        sourceArray = self.filesArray;
    }
    
    NSMutableArray *extractFilesList = [NSMutableArray array];
    NSUInteger current_index = [self.selectedIndexes firstIndex];
    while (current_index != NSNotFound)
    {
        FileItem *fileItem = (FileItem *)([sourceArray objectAtIndex:current_index]);
        [extractFilesList addObject:fileItem];
        
        current_index = [self.selectedIndexes indexGreaterThanIndex: current_index];
    }
    
    if ([self activeTableView].isEditing)
    {
        [self toggleEditButton];
    }
    else
    {
        [self.selectedIndexes removeAllIndexes];
    }

    // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
    // even with UIModalPresentationFormSheet (not the default behavior)
    ExtractViewController *extractViewController = [[ExtractViewController alloc] init];
    extractViewController.connectionManager = self.connectionManager;
    extractViewController.files = extractFilesList;
    extractViewController.destFolder = self.currentFolder;
    extractViewController.delegate = self;
    CustomNavigationController *extractNavController = [[CustomNavigationController alloc] initWithRootViewController:extractViewController];
    extractNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.navigationController presentViewController:extractNavController
                                            animated:YES
                                          completion:nil];
}

- (void)shareSelectedFiles:(UIBarButtonItem*)sender
{
    if ([self.selectedIndexes count] == 0)
    {
        return;
    }
    
    NSMutableArray *sourceArray = nil;
    if (self.searchDisplayController.active)
    {
        sourceArray = self.filteredFilesArray;
    }
    else
    {
        sourceArray = self.filesArray;
    }
    
    NSMutableArray *shareFilesList = [NSMutableArray array];
    NSUInteger current_index = [self.selectedIndexes firstIndex];
    while (current_index != NSNotFound)
    {
        FileItem *fileItem = (FileItem *)([sourceArray objectAtIndex:current_index]);
        [shareFilesList addObject:fileItem];
        
        current_index = [self.selectedIndexes indexGreaterThanIndex: current_index];
    }
    
    if ([self activeTableView].isEditing)
    {
        [self toggleEditButton];
    }
    else
    {
        [self.selectedIndexes removeAllIndexes];
    }

    if ([self.connectionManager supportedSharingFeatures] == CMSupportedSharingNone)
    {
        // If no option is possible, directly create share links
        [self shareFiles:shareFilesList
                duration:0
                password:nil];
    }
    else
    {
        // Show sharing options menu
        ShareViewController *shareViewController = [[ShareViewController alloc] init];
        shareViewController.connectionManager = self.connectionManager;
        shareViewController.files = shareFilesList;
        shareViewController.delegate = self;
        CustomNavigationController *shareNavController = [[CustomNavigationController alloc] initWithRootViewController:shareViewController];
        shareNavController.modalPresentationStyle = UIModalPresentationFormSheet;
        [self.navigationController presentViewController:shareNavController
                                                animated:YES
                                              completion:nil];
    }
}

- (void)invertSelectionButton:(UIBarButtonItem*)sender
{
    NSMutableArray *sourceArray = nil;
    UITableView *tableView = [self activeTableView];
    if (self.searchDisplayController.active)
    {
        sourceArray = self.filteredFilesArray;
    }
    else
    {
        sourceArray = self.filesArray;
    }

    NSInteger index;
    for (index = 0; index < [sourceArray count]; index++)
    {
        NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:0];
        if ([self.selectedIndexes containsIndex:index])
        {
            [self.selectedIndexes removeIndex:index];
            [tableView deselectRowAtIndexPath:path animated:YES];
        }
        else
        {
            [self.selectedIndexes addIndex:index];
            [tableView selectRowAtIndexPath:path animated:YES scrollPosition:UITableViewScrollPositionNone];
        }
    }
    
    // update counts and actions
    [self updateActionBar];
}

- (void)actionButton:(UIBarButtonItem *)button
{
    if (self.sortPopoverController.isPopoverVisible)
    {
        [self.sortPopoverController dismissPopoverAnimated:YES];
        self.sortPopoverController = nil;
    }

    if ((self.actionSheet) && (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad))
    {
        [self.actionSheet dismissWithClickedButtonIndex:self.actionSheet.cancelButtonIndex
                                                     animated:YES];
        self.actionSheet = nil;
    }
    else
    {
        self.actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:nil
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil];
        
        self.actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
        
        self.reloadActionButtonIndex = [self.actionSheet addButtonWithTitle:NSLocalizedString(@"Reload",nil)];
        
        if (ServerSupportsFeature(FolderCreate))
        {
            self.createFolderActionButtonIndex = [self.actionSheet addButtonWithTitle:NSLocalizedString(@"Create Folder",nil)];
        }
        else
        {
            self.createFolderActionButtonIndex = -1;
        }
        
        if (ServerSupportsFeature(FileUpload))
        {
            self.uploadButtonIndex = [self.actionSheet addButtonWithTitle:NSLocalizedString(@"Upload local file here",nil)];
            self.cameraRollSyncButtonIndex = [self.actionSheet addButtonWithTitle:NSLocalizedString(@"Synchronize Camera Roll",nil)];
        }
        else
        {
            self.uploadButtonIndex = -1;
            self.cameraRollSyncButtonIndex = -1;
        }
        
        if (self.userAccount.serverType == SERVER_TYPE_LOCAL)
        {
            self.serverInfoButtonIndex = [self.actionSheet addButtonWithTitle:NSLocalizedString(@"Device info",nil)];
        }
        else
        {
            self.serverInfoButtonIndex = [self.actionSheet addButtonWithTitle:NSLocalizedString(@"Server info",nil)];
        }
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            self.actionSheet.cancelButtonIndex = -1;
            
            [self.actionSheet showFromBarButtonItem:button
                                           animated:YES];
        }
        else
        {
            self.actionSheet.cancelButtonIndex = [self.actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel",nil)];
            
            [self.actionSheet showInView:self.parentViewController.tabBarController.view];
        }
    }
}

- (void)sortButton:(UIBarButtonItem *)button
{
    if (self.sortPopoverController.isPopoverVisible)
    {
        [self.sortPopoverController dismissPopoverAnimated:YES];
        self.sortPopoverController = nil;
    }
    else
    {
        // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
        // even with UIModalPresentationFormSheet (not the default behavior)
        SortItemsViewController *sortItemsViewController = [[SortItemsViewController alloc] initWithSortingType:self.sortingType];
        sortItemsViewController.delegate = self;
        UINavigationController *sortNavController = [[UINavigationController alloc] initWithRootViewController:sortItemsViewController];
//        moveNavController.modalPresentationStyle = UIModalPresentationFormSheet;
        
        self.sortPopoverController = [[UIPopoverController alloc] initWithContentViewController:sortNavController];
        self.sortPopoverController.popoverContentSize = CGSizeMake(320.0, 44*6);
        [self.sortPopoverController presentPopoverFromBarButtonItem:button
                                           permittedArrowDirections:UIPopoverArrowDirectionDown|UIPopoverArrowDirectionUp|UIPopoverArrowDirectionRight
                                                           animated:YES];
    }
}

- (void)selectFileToUpload
{
    UserAccount *localAccount = [[UserAccount alloc] init];
    localAccount.serverType = SERVER_TYPE_LOCAL;
    
    FileItem *rootFolder = [[FileItem alloc] init];
    rootFolder.isDir = YES;
    rootFolder.path = @"/";
    NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
    rootFolder.fullPath = [containerURL.path stringByAppendingString:@"/Documents/"];
    
    ConnectionManager *localCnxManager = [[ConnectionManager alloc] init];
    localCnxManager.delegate = self;
    localCnxManager.userAccount = localAccount;
    
    CustomNavigationController *uploadNavController = [[CustomNavigationController alloc] init];
    uploadNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    UploadBrowserViewController *uploadBrowserViewController = [[UploadBrowserViewController alloc] init];
    uploadBrowserViewController.currentFolder = rootFolder;
    uploadBrowserViewController.delegate = self;
    uploadBrowserViewController.connectionManager = localCnxManager;
    uploadBrowserViewController.title = @"/";
    
    [uploadNavController pushViewController:uploadBrowserViewController animated:NO];
    
    [self.navigationController presentViewController:uploadNavController
                                            animated:YES
                                          completion:nil];
}

- (void)showCameraRollSelectionView
{
    CameraRollSyncViewController *cameraRollSyncVC = [[CameraRollSyncViewController alloc] init];
    cameraRollSyncVC.connectionManager = self.connectionManager;
    cameraRollSyncVC.delegate = self;
    cameraRollSyncVC.currentFolder = self.currentFolder;
    
    CustomNavigationController *cameraRollSyncNavController = [[CustomNavigationController alloc] initWithRootViewController:cameraRollSyncVC];
    cameraRollSyncNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.navigationController presentViewController:cameraRollSyncNavController
                                            animated:YES
                                          completion:nil];
}

#pragma mark - Table view data source

- (UITableView *)activeTableView
{
    UITableView *tableView = nil;
    if (self.searchDisplayController.active)
    {
        tableView = self.searchDisplayController.searchResultsTableView;
    }
    else
    {
        tableView = self.multipleSelectionTableView;
    }
    
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
    if (tableView == self.searchDisplayController.searchResultsTableView)
	{
        return [self.filteredFilesArray count];
    }
	else
	{
        return [self.filesArray count];
    }

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *FileBrowserCellIdentifier = @"FileBrowserCell";
    static NSString *FileBrowserSearchCellIdentifier = @"FileBrowserSearchCell";
    
    FileItem *fileItem = nil;
    if (tableView == self.searchDisplayController.searchResultsTableView)
	{
        fileItem = (FileItem *)([self.filteredFilesArray objectAtIndex:indexPath.row]);
    }
    else
    {
        fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);
    }
    
    if ((self.searchDisplayController.active) &&
        ([self.searchDisplayController.searchBar selectedScopeButtonIndex] == SEARCH_SCOPE_RECURSIVE))
    {
        FileBrowserSearchCell *fileBrowserSearchCell = (FileBrowserSearchCell *)[tableView dequeueReusableCellWithIdentifier:FileBrowserSearchCellIdentifier];
        if (fileBrowserSearchCell == nil)
        {
            fileBrowserSearchCell = [[FileBrowserSearchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                 reuseIdentifier:FileBrowserSearchCellIdentifier];
        }
        
        // Remove long tap gesture recognizer if present
        NSArray *gestureList = [fileBrowserSearchCell gestureRecognizers];
        for (id gesture in gestureList)
        {
            if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]])
            {
                [fileBrowserSearchCell removeGestureRecognizer:gesture];
                break;
            }
        }
        
        // Long tap recognizer
        UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressAction:)];
        [fileBrowserSearchCell addGestureRecognizer:longPressRecognizer];
        
        // Add the OK/Cancel buttons when renaming
        // Release previous accessoryView
        [fileBrowserSearchCell.nameLabel setInputAccessoryView:nil];
        
        UIToolbar *toolbar = [[UIToolbar alloc] init];
        [toolbar setBarStyle:UIBarStyleBlackTranslucent];
        [toolbar sizeToFit];
        
        UIBarButtonItem *flexButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(resignKeyboard:)];
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelKeyboardEntry:)];
        NSArray *itemsArray = [NSArray arrayWithObjects:cancelButton,flexButton, doneButton, nil];
        
        [toolbar setItems:itemsArray];
        
        [fileBrowserSearchCell.nameLabel setInputAccessoryView:toolbar];
        
        // Configure the cell...
        [fileBrowserSearchCell setFileItem:fileItem
                              withDelegate:self
                                    andTag:TAG_TEXTFIELD_FILENAME];
        
        return fileBrowserSearchCell;
    }
    else
    {
        FileBrowserCell *fileBrowserCell = (FileBrowserCell *)[tableView dequeueReusableCellWithIdentifier:FileBrowserCellIdentifier];
        if (fileBrowserCell == nil)
        {
            fileBrowserCell = [[FileBrowserCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                     reuseIdentifier:FileBrowserCellIdentifier];
        }
        
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
        
        // Add the OK/Cancel buttons when renaming
        [fileBrowserCell.nameLabel setInputAccessoryView:nil];
        
        UIToolbar *toolbar = [[UIToolbar alloc] init];
        [toolbar setBarStyle:UIBarStyleBlackTranslucent];
        [toolbar sizeToFit];
        
        UIBarButtonItem *flexButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(resignKeyboard:)];
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelKeyboardEntry:)];
        NSArray *itemsArray = [NSArray arrayWithObjects:cancelButton,flexButton, doneButton, nil];
        
        [toolbar setItems:itemsArray];
        
        [fileBrowserCell.nameLabel setInputAccessoryView:toolbar];
        
        // Configure the cell...
        [fileBrowserCell setFileItem:fileItem
                        withDelegate:self
                              andTag:TAG_TEXTFIELD_FILENAME];
        
        return fileBrowserCell;
    }
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
        if (tableView == self.searchDisplayController.searchResultsTableView)
        {
            sourceArray = self.filteredFilesArray;
        }
        else
        {
            sourceArray = self.filesArray;
        }

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

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        if (editingStyle == UITableViewCellEditingStyleDelete)
        {
            NSMutableArray *sourceArray = nil;
            UITableView *tableView = [self activeTableView];
            if (self.searchDisplayController.active)
            {
                sourceArray = self.filteredFilesArray;
            }
            else
            {
                sourceArray = self.filesArray;
            }

            FileItem *fileItem = (FileItem *)([sourceArray objectAtIndex:indexPath.row]);
            // Delete file from server
            NSMutableArray *filesArray = [NSMutableArray arrayWithObject:fileItem];

            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                      animated:YES];
            if (ServerSupportsFeature(DeleteCancel))
            {
                hud.allowsCancelation = YES;
                hud.tag = TAG_HUD_DELETE;
            }
            hud.delegate = self;
            hud.labelText = NSLocalizedString(@"Deleting", nil);
            
            [self.connectionManager deleteFiles:filesArray];
            
            // Also delete from main tableView if we are in filtering view and if the deleted file is
            // in browsed folder
            if ((self.searchDisplayController.active) &&
                (([self.searchDisplayController.searchBar selectedScopeButtonIndex] == SEARCH_SCOPE_FOLDER) ||
                 (([self.searchDisplayController.searchBar selectedScopeButtonIndex] == SEARCH_SCOPE_RECURSIVE) &&
                  ([self.currentFolder.path isEqualToString:fileItem.shortPath]))))
            {
                NSInteger filesArrayIndex = 0;
                for (FileItem *element in self.filesArray)
                {
                    if ([fileItem.fullPath isEqualToString:element.fullPath])
                    {
                        [self.filesArray removeObjectAtIndex:filesArrayIndex];
                        [self.multipleSelectionTableView  deleteRowsAtIndexPaths:[NSArray arrayWithObject:
                                                                                  [NSIndexPath indexPathForRow:filesArrayIndex inSection:0]]
                                                                withRowAnimation:UITableViewRowAnimationNone];
                        break;
                    }
                    filesArrayIndex++;
                }
            }

            [sourceArray removeObjectAtIndex:indexPath.row];
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.searchDisplayController.active)
    {
        [self.searchBar resignFirstResponder];
    }

    if (tableView.isEditing)
    {
        [self.selectedIndexes addIndex:indexPath.row];
        [self updateActionBar];
    }
    else
    {
        FileItem *fileItem = nil;
        if (tableView == self.searchDisplayController.searchResultsTableView)
        {
            fileItem = (FileItem *)([self.filteredFilesArray objectAtIndex:indexPath.row]);
        }
        else
        {
            fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);
        }

        // Show file if possible
        if (![self openFile:fileItem])
        {
            // For not handled types, show action menu
            [self showActionMenuForItemAtIndexPath:indexPath];
        }
        // deselect the cell
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView.isEditing)
    {
        [self.selectedIndexes removeIndex:indexPath.row];
        [self updateActionBar];
    }
}

#pragma mark - ReaderViewControllerDelegate methods

- (void)dismissReaderViewController:(ReaderViewController *)viewController
{
	[self dismissViewControllerAnimated:YES
                             completion:nil];
}

#pragma mark - Handling long tap

- (void)longPressAction:(UILongPressGestureRecognizer*)longPressRecognizer
{
    /*
     For the long press, the only state of interest is Began.
     When the long press is detected, find the index path of the row (if there is one) at press location.
     If there is a row at the location, create a suitable menu controller and display it.
     */
    if (longPressRecognizer.state == UIGestureRecognizerStateBegan)
    {
        NSIndexPath *pressedIndexPath;
        if (self.searchDisplayController.active)
        {
            [self.searchBar resignFirstResponder];

            pressedIndexPath = [self.searchDisplayController.searchResultsTableView indexPathForRowAtPoint:
                                [longPressRecognizer locationInView:self.searchDisplayController.searchResultsTableView]];
            
            if (pressedIndexPath && (pressedIndexPath.row != NSNotFound) && (pressedIndexPath.section != NSNotFound))
            {
                [self showActionMenuForItemAtIndexPath:pressedIndexPath];
            }
        }
        else
        {
            pressedIndexPath = [self.multipleSelectionTableView indexPathForRowAtPoint:
                                [longPressRecognizer locationInView:self.multipleSelectionTableView]];
            
            if (pressedIndexPath && (pressedIndexPath.row != NSNotFound) && (pressedIndexPath.section != NSNotFound))
            {
                [self showActionMenuForItemAtIndexPath:pressedIndexPath];
            }
        }
        
    }
}

#pragma mark - File view management

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
                MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                          animated:YES];
                if (ServerSupportsFeature(DownloadCancel))
                {
                    hud.allowsCancelation = YES;
                    hud.tag = TAG_HUD_DOWNLOAD;
                }
                hud.delegate = self;
                hud.labelText = NSLocalizedString(@"Preparing subtitle", nil);
                
                NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
                NSString *downloadFilePath = [containerURL.path stringByAppendingString:@"/Documents/.tempSubtitle"];
                self.dlFilePath = downloadFilePath;
                [self.connectionManager downloadFile:file
                                         toLocalName:downloadFilePath];
            }
            return YES;
        }
    }
    return NO;
}

- (BOOL)previewFile:(FileItem *)fileItem
{
    BOOL itemHandled = NO;
    switch ([fileItem fileType])
    {
        case FILETYPE_QT_VIDEO:
        case FILETYPE_QT_AUDIO:
        {
            NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
            
            if ([[defaults objectForKey:kNASTifySettingInternalPlayer] integerValue] == kNASTifySettingInternalPlayerTypeVLCOnly)
            {
                itemHandled = YES;
                {
                    VLCMovieViewController *movieViewController = [[VLCMovieViewController alloc] initWithNibName:nil bundle:nil];
                    
                    movieViewController.url = [NSURL fileURLWithPath:fileItem.fullPath];
                    
                    UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:movieViewController];
                    navCon.modalPresentationStyle = UIModalPresentationFullScreen;
                    [self.navigationController presentViewController:navCon animated:YES completion:nil];
                }
            }
            else
            {
                itemHandled = YES;
                // Internal player can handle this media
                CustomMoviePlayerViewController *mp = [[CustomMoviePlayerViewController alloc] initWithContentURL:[NSURL fileURLWithPath:fileItem.fullPath]];
                mp.allowsAirPlay = NO;
                if (mp)
                {
                    [self presentViewController:mp animated:YES completion:nil];
                    [mp startPlaying];
                }
            }
            break;
        }
        case FILETYPE_VLC_VIDEO:
        case FILETYPE_VLC_AUDIO:
        {
            itemHandled = YES;
            {
                VLCMovieViewController *movieViewController = [[VLCMovieViewController alloc] initWithNibName:nil bundle:nil];
                
                movieViewController.url = [NSURL fileURLWithPath:fileItem.fullPath];
                
                UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:movieViewController];
                navCon.modalPresentationStyle = UIModalPresentationFullScreen;
                [self.navigationController presentViewController:navCon animated:YES completion:nil];
            }
            break;
        }
        case FILETYPE_PDF:
        {
            NSString *phrase = nil; // Document password (for unlocking most encrypted PDF files)
            
            itemHandled = YES;
            ReaderDocument *document = [[ReaderDocument alloc] initWithFilePath:fileItem.fullPath password:phrase];
            
            if (document != nil) // Must have a valid ReaderDocument object in order to proceed
            {
                ReaderViewController *readerViewController = [[ReaderViewController alloc] initWithReaderDocument:document];
                
                readerViewController.delegate = self; // Set the ReaderViewController delegate to self
                
                readerViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
                readerViewController.modalPresentationStyle = UIModalPresentationFullScreen;
                
                [self.navigationController presentViewController:readerViewController
                                                        animated:YES
                                                      completion:nil];
            }
            break;
        }
        case FILETYPE_TEXT:
        {
            itemHandled = YES;
            RBFilePreviewer *preview = [[RBFilePreviewer alloc] initWithFile:[NSURL fileURLWithPath:fileItem.fullPath]];
            preview.navBarTintColor = [UIColor blackColor];
            preview.toolBarTintColor = [UIColor blackColor];
            [self.navigationController pushViewController:preview animated:YES];
            break;
        }
        case FILETYPE_PHOTO:
        {
            itemHandled = YES;
            // View all photos in list
            self.photos = [NSMutableArray arrayWithObject:fileItem.fullPath];
            
            
            NSInteger photoIndex = 0;
            
            // Create & present browser
            MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
            // Set options
            browser.displayNavArrows = YES;
            browser.displayActionButton = YES;
            
            [browser setCurrentPhotoIndex:photoIndex];
            
            // Present navigation controller
            UINavigationController *navControler = [[UINavigationController alloc] initWithRootViewController:browser];
            [self.navigationController presentViewController:navControler
                                                    animated:YES
                                                  completion:nil];
            break;
        }
        default:
        {
            // Nothing to do
            break;
        }
            
    }
    return itemHandled;
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
        case FILETYPE_ARCHIVE:
        {
            itemHandled = YES;
            
            NSMutableArray *fileFolderIds = [NSMutableArray arrayWithArray:fileItem.objectIds];
            // We remove the last item which is the file's Id
            [fileFolderIds removeLastObject];
            
            FileItem *fileFolder = [[FileItem alloc] init];
            fileFolder.isDir = YES;
            fileFolder.shortPath = fileItem.shortPath;
            fileFolder.path = fileItem.shortPath;
            fileFolder.fullPath = [fileItem.fullPath stringByDeletingLastPathComponent];
            fileFolder.objectIds = [NSArray arrayWithArray:fileFolderIds];
            
            // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
            // even with UIModalPresentationFormSheet (not the default behavior)
            ExtractViewController *extractViewController = [[ExtractViewController alloc] init];
            extractViewController.connectionManager = self.connectionManager;
            extractViewController.files = [NSArray arrayWithObject:fileItem];
            extractViewController.destFolder = fileFolder;
            extractViewController.delegate = self;
            CustomNavigationController *extractNavController = [[CustomNavigationController alloc] initWithRootViewController:extractViewController];
            extractNavController.modalPresentationStyle = UIModalPresentationFormSheet;
            [self.navigationController presentViewController:extractNavController
                                                    animated:YES
                                                  completion:nil];
            break;
        }
        case FILETYPE_QT_VIDEO:
        case FILETYPE_QT_AUDIO:
        {
            if (([self.connectionManager pluginRespondsToSelector:@selector(urlForFile:)]) ||
                ([self.connectionManager pluginRespondsToSelector:@selector(urlForVideo:)]))
            {
                NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
                self.videoNetworkConnection = [self.connectionManager urlForVideo:fileItem];
                
                BOOL useExternalPlayer = NO;
                if (([[defaults objectForKey:kNASTifySettingPlayerType] integerValue] == kNASTifySettingPlayerTypeExternal) &&
                    (self.videoNetworkConnection.urlType != URLTYPE_LOCAL))
                {
                    useExternalPlayer = YES;
                }
                
                if (useExternalPlayer)
                {
                    NSString *stringURL = [self.videoNetworkConnection.url absoluteString];
                    BOOL *playerFound = NO;
                    switch ([[defaults objectForKey:kNASTifySettingExternalPlayerType] integerValue])
                    {
                        case kNASTifySettingExternalPlayerTypeVlc:
                        {
                            playerFound = YES;
                            stringURL = [NSString stringWithFormat:@"vlc://%@",stringURL];
                            break;
                        }
                        case kNASTifySettingExternalPlayerTypeAceplayer:
                        {
                            playerFound = YES;
                            stringURL = [NSString stringWithFormat:@"aceplayer://%@",stringURL];
                            break;
                        }
                        case kNASTifySettingExternalPlayerTypeGplayer:
                        {
                            playerFound = YES;
                            stringURL = [NSString stringWithFormat:@"gplayer://%@",stringURL];
                            break;
                        }
                        case kNASTifySettingExternalPlayerTypeOplayer:
                        {
                            playerFound = YES;
                            stringURL = [NSString stringWithFormat:@"oplayer://%@",stringURL];
                            break;
                        }
                        case kNASTifySettingExternalPlayerTypeGoodplayer:
                        {
                            playerFound = YES;
                            stringURL = [NSString stringWithFormat:@"goodplayer://%@",stringURL];
                            break;
                        }
                        default:
                        {
                            break;
                        }
                    }
                    NSURL *url = [NSURL URLWithString:stringURL];
                    if ((playerFound) && ([[UIApplication sharedApplication] canOpenURL:url]))
                    {
                        itemHandled = YES;
                        [[UIApplication sharedApplication] openURL:url];
                    }
                    
                }
                else
                {
                    if ((ServerSupportsFeature(GoogleCast) && _gcController.deviceManager && _gcController.deviceManager.isConnected) ||
                        (([[defaults objectForKey:kNASTifySettingInternalPlayer] integerValue] == kNASTifySettingInternalPlayerTypeVLCOnly) && (ServerSupportsFeature(VLCPlayer))))
                    {
                        // If GoogleCast connected, use VLC player
                        itemHandled = YES;
                        if (![self getSubtitleFileForMedia:fileItem])
                        {
                            VLCMovieViewController *movieViewController = [[VLCMovieViewController alloc] initWithNibName:nil bundle:nil];
                            
                            movieViewController.url = self.videoNetworkConnection.url;
                            
                            UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:movieViewController];
                            navCon.modalPresentationStyle = UIModalPresentationFullScreen;
                            [self.navigationController presentViewController:navCon animated:YES completion:nil];
                        }
                    }
                    else if (ServerSupportsFeature(QTPlayer))
                    {
                        itemHandled = YES;
                        // Internal player can handle this media
                        CustomMoviePlayerViewController *mp = [[CustomMoviePlayerViewController alloc] initWithContentURL:self.videoNetworkConnection.url];
                        mp.allowsAirPlay = ServerSupportsFeature(AirPlay);
                        if (mp)
                        {
                            [self presentViewController:mp animated:YES completion:nil];
                            [mp startPlaying];
                        }
                    }
                    else if (ServerSupportsFeature(VLCPlayer))
                    {
                        itemHandled = YES;
                        // Fallback to VLC media player
                        if (![self getSubtitleFileForMedia:fileItem])
                        {
                            VLCMovieViewController *movieViewController = [[VLCMovieViewController alloc] initWithNibName:nil bundle:nil];
                            
                            movieViewController.url = self.videoNetworkConnection.url;
                            
                            UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:movieViewController];
                            navCon.modalPresentationStyle = UIModalPresentationFullScreen;
                            [self.navigationController presentViewController:navCon animated:YES completion:nil];
                        }
                    }
                }
            }
            break;
        }
        case FILETYPE_VLC_VIDEO:
        case FILETYPE_VLC_AUDIO:
        {
            if (([self.connectionManager pluginRespondsToSelector:@selector(urlForFile:)]) ||
                ([self.connectionManager pluginRespondsToSelector:@selector(urlForVideo:)]))
            {
                NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
                self.videoNetworkConnection = [self.connectionManager urlForVideo:fileItem];
                BOOL useExternalPlayer = NO;
                if (([[defaults objectForKey:kNASTifySettingPlayerType] integerValue] == kNASTifySettingPlayerTypeExternal) &&
                    (self.videoNetworkConnection.urlType != URLTYPE_LOCAL))
                {
                    useExternalPlayer = YES;
                }
                
                if (useExternalPlayer)
                {
                    NSString *stringURL = [self.videoNetworkConnection.url absoluteString];
                    BOOL *playerFound = NO;
                    switch ([[defaults objectForKey:kNASTifySettingExternalPlayerType] integerValue])
                    {
                        case kNASTifySettingExternalPlayerTypeVlc:
                        {
                            playerFound = YES;
                            stringURL = [NSString stringWithFormat:@"vlc://%@",stringURL];
                            break;
                        }
                        case kNASTifySettingExternalPlayerTypeAceplayer:
                        {
                            playerFound = YES;
                            stringURL = [NSString stringWithFormat:@"aceplayer://%@",stringURL];
                            break;
                        }
                        case kNASTifySettingExternalPlayerTypeGplayer:
                        {
                            playerFound = YES;
                            stringURL = [NSString stringWithFormat:@"gplayer://%@",stringURL];
                            break;
                        }
                        case kNASTifySettingExternalPlayerTypeOplayer:
                        {
                            playerFound = YES;
                            stringURL = [NSString stringWithFormat:@"oplayer://%@",stringURL];
                            break;
                        }
                        case kNASTifySettingExternalPlayerTypeGoodplayer:
                        {
                            playerFound = YES;
                            stringURL = [NSString stringWithFormat:@"goodplayer://%@",stringURL];
                            break;
                        }
                        default:
                        {
                            break;
                        }
                    }
                    NSURL *url = [NSURL URLWithString:stringURL];
                    if ((playerFound) && ([[UIApplication sharedApplication] canOpenURL:url]))
                    {
                        itemHandled = YES;
                        [[UIApplication sharedApplication] openURL:url];
                    }
                }
                else if (ServerSupportsFeature(VLCPlayer))
                {
                    itemHandled = YES;
                    if (![self getSubtitleFileForMedia:fileItem])
                    {
                        VLCMovieViewController *movieViewController = [[VLCMovieViewController alloc] initWithNibName:nil bundle:nil];
                        
                        movieViewController.url = self.videoNetworkConnection.url;
                        
                        UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:movieViewController];
                        navCon.modalPresentationStyle = UIModalPresentationFullScreen;
                        [self.navigationController presentViewController:navCon animated:YES completion:nil];
                    }
                }
            }
            break;
        }
        case FILETYPE_PDF:
        {
            NSString *phrase = nil; // Document password (for unlocking most encrypted PDF files)
            
            NetworkConnection *networkConnection = [self.connectionManager urlForFile:fileItem];
            
            // Only possible if file is available locally
            if (networkConnection.urlType == URLTYPE_LOCAL)
            {
                itemHandled = YES;
                ReaderDocument *document = [[ReaderDocument alloc] initWithFilePath:[networkConnection.url relativePath] password:phrase];
                
                if (document != nil) // Must have a valid ReaderDocument object in order to proceed
                {
                    ReaderViewController *readerViewController = [[ReaderViewController alloc] initWithReaderDocument:document];
                    
                    readerViewController.delegate = self; // Set the ReaderViewController delegate to self
                    
                    readerViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
                    readerViewController.modalPresentationStyle = UIModalPresentationFullScreen;
                    
                    [self.navigationController presentViewController:readerViewController
                                                            animated:YES
                                                          completion:nil];
                }
            }
            break;
        }
        case FILETYPE_TEXT:
        {
            NetworkConnection *networkConnection = [self.connectionManager urlForFile:fileItem];
            
            // Only possible if file is available locally
            if (networkConnection.urlType == URLTYPE_LOCAL)
            {
                itemHandled = YES;
                RBFilePreviewer *preview = [[RBFilePreviewer alloc] initWithFile:networkConnection.url];
                preview.navBarTintColor = [UIColor blackColor];
                preview.toolBarTintColor = [UIColor blackColor];
                [self.navigationController pushViewController:preview animated:YES];
            }
            break;
        }
        case FILETYPE_PHOTO:
        {
            if ([self.connectionManager pluginRespondsToSelector:@selector(urlForFile:)])
            {
                itemHandled = YES;
                // View all photos in list
                self.photos = [NSMutableArray array];
                
                NSMutableArray *sourceArray = nil;
                if (self.searchDisplayController.active)
                {
                    sourceArray = self.filteredFilesArray;
                }
                else
                {
                    sourceArray = self.filesArray;
                }
                
                NSInteger photoIndex = 0;
                NSInteger index = 0;
                for (FileItem *file in sourceArray)
                {
                    if (file == fileItem)
                    {
                        photoIndex = index;
                    }
                    if ([file fileType] == FILETYPE_PHOTO)
                    {
                        [self.photos addObject:file];
                        index++;
                    }
                }
                
                // Create & present browser
                MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
                // Set options
                browser.displayNavArrows = YES;
                browser.displayActionButton = YES;
                
                [browser setCurrentPhotoIndex:photoIndex];
                
                // Present navigation controller
                UINavigationController *navControler = [[UINavigationController alloc] initWithRootViewController:browser];
                [self.navigationController presentViewController:navControler
                                                        animated:YES
                                                      completion:nil];
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

#pragma mark - UIActionSheetDelegate

- (void)showOpenInMenu:(UITableViewCell *)cell
{
    [self.documentInteractionController presentOpenInMenuFromRect:cell.frame
                                                           inView:cell.superview
                                                         animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == -1)
    {
		// Do nothing
		return;
	}
    
    if (actionSheet == _gcActionSheet)
    {
        if (_gcController.selectedDevice == nil)
        {
            if (buttonIndex < _gcController.deviceScanner.devices.count)
            {
                _gcController.selectedDevice = _gcController.deviceScanner.devices[buttonIndex];
                NSLog(@"Selecting device:%@", _gcController.selectedDevice.friendlyName);
                [_gcController connectToDevice];
            }
        }
        else
        {
            if (buttonIndex == _gcActionSheet.destructiveButtonIndex)
            {  //Disconnect button
                NSLog(@"Disconnecting device:%@", _gcController.selectedDevice.friendlyName);
                // New way of doing things: We're not going to stop the applicaton. We're just going
                // to leave it.
                [_gcController.deviceManager leaveApplication];
                // If you want to force application to stop, uncomment below
                //[self.deviceManager stopApplicationWithSessionID:self.applicationMetadata.sessionID];
                [_gcController.deviceManager disconnect];
                
                [_gcController deviceDisconnected];
                [self updateGCState];
            }
            else if (buttonIndex == 0)
            {
                // Join the existing session.
                VLCMovieViewController *movieViewController = [[VLCMovieViewController alloc] initWithNibName:nil bundle:nil];
                
                movieViewController.url = nil;

                UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:movieViewController];
                navCon.modalPresentationStyle = UIModalPresentationFullScreen;
                [self.navigationController presentViewController:navCon animated:YES completion:nil];
            }
        }
    }
    else
    {
        NSMutableArray *sourceArray = nil;
        if (self.searchDisplayController.active)
        {
            sourceArray = self.filteredFilesArray;
        }
        else
        {
            sourceArray = self.filesArray;
        }
        
        if (actionSheet == self.actionSheet)
        {
            if (buttonIndex == self.createFolderActionButtonIndex)
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Create folder",nil)
                                                                message:nil
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"Cancel",nil)
                                                      otherButtonTitles:NSLocalizedString(@"OK",nil), nil];
                alert.alertViewStyle = UIAlertViewStylePlainTextInput;
                alert.tag = TAG_ALERT_CREATE_FOLDER;
                [alert show];
            }
            else if (buttonIndex == self.reloadActionButtonIndex)
            {
                [self.connectionManager listForPath:self.currentFolder];
            }
            else if (buttonIndex == self.uploadButtonIndex)
            {
                /* For some reasons, perform view creation from here will cause memory issues,
                 this is a dirty workaround until a proper solution is found */
                [self performSelector:@selector(selectFileToUpload) withObject:nil afterDelay:0.5];
            }
            else if (buttonIndex == self.serverInfoButtonIndex)
            {
                NSString *message = [NSString string];
                NSString *title = nil;
                if (self.userAccount.serverType == SERVER_TYPE_LOCAL)
                {
                    title = NSLocalizedString(@"Device info",nil);
                }
                else
                {
                    title = NSLocalizedString(@"Server info",nil);
                }
                NSArray *array = [self.connectionManager serverInfo];
                for (NSString *line in array)
                {
                    message = [message stringByAppendingFormat:@"%@\n",line];
                }
                
                UIAlertView *info = [[UIAlertView alloc] initWithTitle:title
                                                               message:message
                                                              delegate:nil
                                                     cancelButtonTitle:nil
                                                     otherButtonTitles:NSLocalizedString(@"OK", nil),nil];
                [info show];
            }
            else if (buttonIndex == self.cameraRollSyncButtonIndex)
            {
                /* For some reasons, perform view creation from here will cause memory issues,
                 this is a dirty workaround until a proper solution is found */
                [self performSelector:@selector(showCameraRollSelectionView) withObject:nil afterDelay:0.5];
            }
        }
        else if (actionSheet == self.itemActionSheet)
        {
            FileItem *fileItem = (FileItem *)([sourceArray objectAtIndex:actionSheet.tag]);
            if (actionSheet.destructiveButtonIndex == buttonIndex)
            {
                [self.selectedIndexes addIndex:actionSheet.tag];

                [self deleteSelectedFiles:nil];
            }
            else if (buttonIndex == self.renameButtonIndex)
            {
                UITableView *tableView = [self activeTableView];
                
                FileBrowserCell *cell = (FileBrowserCell *)[tableView cellForRowAtIndexPath:
                                                            [NSIndexPath indexPathForRow:actionSheet.tag inSection:0]];
                
                // Save the cell for handling everything right after ...
                self.editedCell = cell;
                
                // Disable selection of cells
                tableView.allowsSelection = NO;
                
                /* Remove long tap handling (need to be restored at the end of renaming) */
                NSInteger rows = [tableView numberOfRowsInSection:0];
                NSInteger index;
                for (index = 0; index < rows; index++)
                {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                    UITableViewCell *oneCell = [tableView cellForRowAtIndexPath:indexPath];
                    
                    // Disable touch detection for cells (restored once renaming is finished)
                    oneCell.userInteractionEnabled = NO;
                    
                    NSArray *gestureList = [oneCell gestureRecognizers];
                    for (id gesture in gestureList)
                    {
                        if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]])
                        {
                            [oneCell removeGestureRecognizer:gesture];
                            break;
                        }
                    }
                }
                
                // enable touch detection for edited cell
                self.editedCell.userInteractionEnabled = YES;
                
                // Keyboard notifications for tableView insets update
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(keyboardWillShow:)
                                                             name:UIKeyboardWillShowNotification
                                                           object:nil];
                
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(keyboardWillHide:)
                                                             name:UIKeyboardWillHideNotification
                                                           object:nil];
                
                /* Start editing */
                [cell setEditable];
                [cell.nameLabel becomeFirstResponder];
            }
            else if (buttonIndex == self.moveCopyButtonIndex)
            {
                [self.selectedIndexes addIndex:actionSheet.tag];
                
                /* For some reasons, perform view creation from here will cause memory issues,
                   this is a dirty workaround until a proper solution is found */
                [self performSelector:@selector(copyMoveSelectedFiles:) withObject:nil afterDelay:0.5];
            }
            else if (buttonIndex == self.compressButtonIndex)
            {
                [self.selectedIndexes addIndex:actionSheet.tag];
                
                /* For some reasons, perform view creation from here will cause memory issues,
                 this is a dirty workaround until a proper solution is found */
                [self performSelector:@selector(compressSelectedFiles:) withObject:nil afterDelay:0.5];
            }
            else if (buttonIndex == self.extractButtonIndex)
            {
                [self.selectedIndexes addIndex:actionSheet.tag];
                
                /* For some reasons, perform view creation from here will cause memory issues,
                 this is a dirty workaround until a proper solution is found */
                [self performSelector:@selector(extractSelectedFiles:) withObject:nil afterDelay:0.5];
            }
            else if (buttonIndex == self.shareButtonIndex)
            {
                [self.selectedIndexes addIndex:actionSheet.tag];
                
                /* For some reasons, perform view creation from here will cause memory issues,
                 this is a dirty workaround until a proper solution is found */
                [self performSelector:@selector(shareSelectedFiles:) withObject:nil afterDelay:0.5];
            }
            else if (buttonIndex == self.openInButtonIndex)
            {
                NSURL *fileURL = [self.connectionManager urlForFile:fileItem].url;
                self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
                
                self.documentInteractionController.delegate = self;
                
                // Present an Open in menu
                CGRect openInRect;
                UIView *openInView = nil;
                
                FileBrowserCell *openInCell;
                if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                {
                    openInRect = CGRectZero;
                    openInView = self.view.superview;
                    
                    UITableView *tableView = [self activeTableView];
                    
                    // Parse visible cells to find the good one
                    for (FileBrowserCell *cell in tableView.visibleCells)
                    {
                        if ([cell.nameLabel.text isEqualToString:fileItem.name])
                        {
                            openInCell = cell;
                            [self performSelector:@selector(showOpenInMenu:) withObject:openInCell afterDelay:0.1];
                            break;
                        }
                    }
                }
                else
                {
                    openInRect = CGRectZero;
                    openInView = self.view.superview;
                    [self.documentInteractionController presentOpenInMenuFromRect:openInRect
                                                                           inView:openInView
                                                                         animated:YES];
                }
            }
            else if (buttonIndex == self.downloadButtonIndex)
            {
                self.videoNetworkConnection = nil;
                
                self.downloadAction = DOWNLOAD_ACTION_DOWNLOAD;
                MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                          animated:YES];
                if (ServerSupportsFeature(DownloadCancel))
                {
                    hud.allowsCancelation = YES;
                    hud.tag = TAG_HUD_DOWNLOAD;
                }
                hud.delegate = self;
                hud.labelText = NSLocalizedString(@"Downloading", nil);
                
                NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
                NSString *downloadFilePath = [containerURL.path stringByAppendingFormat:@"/Documents/%@",fileItem.name];
                [self.connectionManager downloadFile:fileItem
                                         toLocalName:downloadFilePath];
            }
            else if (buttonIndex == self.ejectButtonIndex)
            {
                MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                          animated:YES];
                hud.delegate = self;
                hud.labelText = NSLocalizedString(@"Ejecting", nil);
                
                [self.connectionManager ejectFile:fileItem];
            }
            else if (buttonIndex == self.previewButtonIndex)
            {
                self.downloadAction = DOWNLOAD_ACTION_PREVIEW;
                self.sourceFileItem = fileItem;
                
                MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                          animated:YES];
                if (ServerSupportsFeature(DownloadCancel))
                {
                    hud.allowsCancelation = YES;
                    hud.tag = TAG_HUD_DOWNLOAD;
                }
                hud.delegate = self;
                hud.labelText = NSLocalizedString(@"Downloading for preview", nil);
                
                NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
                NSString *downloadFilePath = [containerURL.path stringByAppendingFormat:@"/Cache/%@",fileItem.name];
                self.dlFilePath = downloadFilePath;
                [self.connectionManager downloadFile:fileItem
                                         toLocalName:downloadFilePath];
            }
        }
    }
}

- (void)hudDidCancel:(MBProgressHUD *)hud;
{
    switch (hud.tag)
    {
        case TAG_HUD_DOWNLOAD:
        {
            [self.connectionManager cancelDownloadTask];
            [hud hide:YES];
            switch (self.downloadAction)
            {
                case DOWNLOAD_ACTION_SUBTITLE:
                {
                    // Subtitle downloading canceled, play the video anyway
                    VLCMovieViewController *movieViewController = [[VLCMovieViewController alloc] initWithNibName:nil bundle:nil];
                    movieViewController.url = self.videoNetworkConnection.url;
                    
                    UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:movieViewController];
                    navCon.modalPresentationStyle = UIModalPresentationFullScreen;
                    [self.navigationController presentViewController:navCon animated:YES completion:nil];
                    break;
                }
                default:
                {
                    // Nothing to do
                    break;
                }
            }
            if (self.videoNetworkConnection)
            {
            }
            break;
        }
        case TAG_HUD_UPLOAD:
        {
            [self.connectionManager cancelUploadTask];
            [hud hide:YES];
            break;
        }
        case TAG_HUD_DELETE:
        {
            [self.connectionManager cancelDeleteTask];
            
            // Update file list as delete process has been cancelled
            [self.connectionManager listForPath:self.currentFolder];
            [self.connectionManager spaceInfoAtPath:self.currentFolder];
            [hud hide:YES];
            break;
        }
        case TAG_HUD_COPY:
        {
            [self.connectionManager cancelCopyTask];
            // Update free space as copy process has been cancelled
            [self.connectionManager spaceInfoAtPath:self.currentFolder];
            [hud hide:YES];
            break;
        }
        case TAG_HUD_MOVE:
        {
            [self.connectionManager cancelMoveTask];
            // Update file list as move process has been cancelled
            [self.connectionManager listForPath:self.currentFolder];
            [hud hide:YES];
            break;
        }
        case TAG_HUD_COMPRESS:
        {
            [self.connectionManager cancelCompressTask];
            [hud hide:YES];
            break;
        }
        case TAG_HUD_EXTRACT:
        {
            [self.connectionManager cancelExtractTask];
            [hud hide:YES];

            break;
        }
        case TAG_HUD_SEARCH:
        {
            [self.connectionManager cancelSearchTask];
            [hud hide:YES];
            break;
        }
        default:
            break;
    }
}

#pragma mark - UIDocumentInteractionControllerDelegate methods

- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application
{
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller
{
}

#pragma mark -
#pragma mark MWPhotoBrowserDelegate

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser
{
    return self.photos.count;
}

- (MWPhoto *)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index
{
    MWPhoto *photo = nil;
    if (index < self.photos.count)
    {
        id element = [self.photos objectAtIndex:index];
        if ([element isKindOfClass:[FileItem class]])
        {
            FileItem *file = element;
            photo = [MWPhoto photoWithURL:[self.connectionManager urlForFile:file].url];
            photo.caption = file.name;
        }
        else
        {
            photo = [MWPhoto photoWithURL:[NSURL fileURLWithPath:element]];
        }
        
        photo.options = SDWebImageDownloaderHandleCookies;
        if (self.userAccount.acceptUntrustedCertificate)
        {
            photo.options |= SDWebImageDownloaderAllowInvalidSSLCertificates;
        }
        if (ServerSupportsFeature(CacheImage) == FALSE)
        {
            photo.options |= SDWebImageCacheMemoryOnly;
        }
    }
    return photo;
}

#pragma mark - TextFieldDelegate & keyboard related Methods

- (void)cancelKeyboardEntry:(UIBarButtonItem *)button
{
    // Restore previous name and make keyboard disappear
    self.editedCell.nameLabel.text = self.editedCell.oldName;
    [self.editedCell.nameLabel resignFirstResponder];
    
    // Remove keyboard notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (void)resignKeyboard:(UIBarButtonItem *)button
{
    [self.editedCell.nameLabel resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	switch (textField.tag)
    {
		case TAG_TEXTFIELD_FILENAME:
		{
			[textField resignFirstResponder];
			return YES;
			break;
		}
		default:
			break;
	}
	return NO;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	switch (textField.tag)
    {
		case TAG_TEXTFIELD_FILENAME:
		{
			[textField resignFirstResponder];
            
            // Remove keyboard notifications
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:UIKeyboardWillShowNotification
                                                          object:nil];
            
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:UIKeyboardWillHideNotification
                                                          object:nil];
            

            NSMutableArray *sourceArray = nil;
            UITableView *tableView = nil;
            if (self.searchDisplayController.active)
            {
                sourceArray = self.filteredFilesArray;
                tableView = self.searchDisplayController.searchResultsTableView;
            }
            else
            {
                sourceArray = self.filesArray;
                tableView = self.multipleSelectionTableView;
            }

            // If the name changed, proceed with rename
            if (![textField.text isEqualToString:self.editedCell.oldName])
            {
                // Parse the filesArray to find the element here
                for (FileItem *file in sourceArray)
                {
                    if ([file.name isEqualToString:self.editedCell.oldName])
                    {
                        [self.connectionManager renameFile:[file copy]
                                                    toName:textField.text
                                                    atPath:self.currentFolder];

                        NSRange filenameRange = NSMakeRange([file.path length]-[file.name length], [file.name length]);
                        file.path =  [file.path stringByReplacingCharactersInRange:filenameRange
                                                           withString:textField.text];
                        filenameRange = NSMakeRange([file.fullPath length]-[file.name length], [file.name length]);
                        file.fullPath = [file.fullPath stringByReplacingCharactersInRange:filenameRange
                                                           withString:textField.text];

                        file.name = textField.text;
                        if ((!file.isDir) && ([[file.name componentsSeparatedByString:@"."] count] > 1))
                        {
                            file.type = [[file.name componentsSeparatedByString:@"."] lastObject];
                        }
                        break;
                    }
                }
                
                if (self.searchDisplayController.active)
                {
                    // If the name is not matching the search string anymore, remove it
                    NSRange range = [self.editedCell.nameLabel.text rangeOfString:self.searchDisplayController.searchBar.text
                                                                          options:(NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch)];
                    if (range.location == NSNotFound)
                    {
                        NSInteger index;
                        for (index = 0; index < [sourceArray count]; index++)
                        {
                            FileItem *item = [sourceArray objectAtIndex:index];
                            if ([item.name isEqualToString:textField.text])
                            {
                                [sourceArray removeObjectAtIndex:index];
                                break;
                            }
                        }
                    }
                }
                
                self.editedCell.oldName = textField.text;
            }
            
			[self.editedCell setUneditable];
			
            // Restore selection of files
            tableView.allowsSelection = YES;
            
			/* Restore long tap handling (was removed at start of renaming) */
            NSInteger rows = [tableView numberOfRowsInSection:0];
            NSInteger index;
            for (index = 0; index < rows; index++)
            {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                UITableViewCell *oneCell = [tableView cellForRowAtIndexPath:indexPath];
                
				// Long tap recognizer
                UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                                  action:@selector(longPressAction:)];
                [oneCell addGestureRecognizer:longPressRecognizer];

				// Enable touch detection for cells
				oneCell.userInteractionEnabled = YES;
            }
            
            [tableView reloadData];
			break;
		}
		default:
			break;
	}
}

#pragma mark - UIAlertViewDelegate functions

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == -1)
		return;
    
    NSMutableArray *sourceArray = nil;
    UITableView *tableView = nil;
    if (self.searchDisplayController.active)
    {
        sourceArray = self.filteredFilesArray;
        tableView = self.searchDisplayController.searchResultsTableView;
    }
    else
    {
        sourceArray = self.filesArray;
        tableView = self.multipleSelectionTableView;
    }

    switch (alertView.tag)
    {
        case TAG_ALERT_DELETE_FILES:
        {
            if (alertView.firstOtherButtonIndex == buttonIndex)
            {
                // Delete files if ok
                NSMutableArray *filesArray = [NSMutableArray array];
                
                NSUInteger current_index = [self.selectedIndexes firstIndex];
                NSMutableArray *indexPathsForSelectedIndexes = [NSMutableArray array];
                while (current_index != NSNotFound)
                {
                    FileItem *fileItem = (FileItem *)([sourceArray objectAtIndex:current_index]);
                    [filesArray addObject:fileItem];
                    
                    [indexPathsForSelectedIndexes addObject:[NSIndexPath indexPathForRow:current_index inSection:0]];
                    
                    current_index = [self.selectedIndexes indexGreaterThanIndex: current_index];
                    
                    // Also delete from main tableView if we are in filtering view and if the deleted file is
                    // in browsed folder
                    if ((self.searchDisplayController.active) &&
                        (([self.searchDisplayController.searchBar selectedScopeButtonIndex] == SEARCH_SCOPE_FOLDER) ||
                         (([self.searchDisplayController.searchBar selectedScopeButtonIndex] == SEARCH_SCOPE_RECURSIVE) &&
                          ([self.currentFolder.path isEqualToString:fileItem.shortPath]))))
                    {
                        NSInteger filesArrayIndex = 0;
                        for (FileItem *element in self.filesArray)
                        {
                            if ([fileItem.fullPath isEqualToString:element.fullPath])
                            {
                                [self.filesArray removeObjectAtIndex:filesArrayIndex];
                                [self.multipleSelectionTableView  deleteRowsAtIndexPaths:[NSArray arrayWithObject:
                                                                                          [NSIndexPath indexPathForRow:filesArrayIndex inSection:0]]
                                                                        withRowAnimation:UITableViewRowAnimationNone];
                                break;
                            }
                            filesArrayIndex++;
                        }
                    }
                }
                
                MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                          animated:YES];
                if (ServerSupportsFeature(DeleteCancel))
                {
                    hud.allowsCancelation = YES;
                    hud.tag = TAG_HUD_DELETE;
                }
                hud.delegate = self;
                hud.labelText = NSLocalizedString(@"Deleting", nil);
                
                [self.connectionManager deleteFiles:filesArray];
                
                NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
                for (NSIndexPath *indexPath in indexPathsForSelectedIndexes)
                {
                    [indexSet addIndex:indexPath.row];
                }
                [sourceArray removeObjectsAtIndexes:indexSet];
                
                [tableView deleteRowsAtIndexPaths:indexPathsForSelectedIndexes
                                 withRowAnimation:UITableViewRowAnimationFade];
                
                if ([self activeTableView].isEditing)
                {
                    [self toggleEditButton];
                }
                else
                {
                    [self.selectedIndexes removeAllIndexes];
                }
            }
            break;
        }
        case TAG_ALERT_CREATE_FOLDER:
        {
            NSString *folderName = [alertView textFieldAtIndex:0].text;
            if ((buttonIndex == alertView.firstOtherButtonIndex) &&
                (folderName != nil) &&
                (![folderName isEqualToString:@""]))
            {
                [self createFolder:folderName
                          inFolder:self.currentFolder];
            }
            break;
        }
        case TAG_ALERT_OTP:
        {
            if (buttonIndex == alertView.cancelButtonIndex)
            {
                // Go back to servers list
                [self.navigationController popToRootViewControllerAnimated:YES];
            }
            else if (buttonIndex == alertView.firstOtherButtonIndex)
            {
                [self sendOTP:[alertView textFieldAtIndex:0].text];
            }
            else if (buttonIndex == alertView.firstOtherButtonIndex + 1)
            {
                // Send emergency code request
                [self sendOTPEmergencyCode];
            }
            break;
        }
        case TAG_ALERT_DO_NOTHING:
        {
            // Do nothing
            break;
        }
        case TAG_ALERT_DISCONNECT:
        {
            if (buttonIndex == alertView.firstOtherButtonIndex)
            {
                BOOL needToWaitLogout = FALSE;
                // We are going back to servers list, logout from server
                needToWaitLogout = [self.connectionManager logout];
                
                if (needToWaitLogout)
                {
                    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                              animated:YES];
                    hud.delegate = self;
                    hud.labelText = NSLocalizedString(@"Disconnect", nil);
                }
                else
                {
                    self.isConnected = FALSE;
                    [self.navigationController popViewControllerAnimated:YES];
                }
            }
            break;
        }
        default:
        {
            NSLog(@"Missing action");
            break;
        }
    }
}

#pragma mark - CompressViewController delegate

- (void)compressFiles:(NSArray *)files
            toArchive:(NSString *)archive
          archiveType:(ARCHIVE_TYPE)archiveType
     compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel
             password:(NSString *)password
            overwrite:(BOOL)overwrite
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                              animated:YES];
    if (ServerSupportsFeature(CompressCancel))
    {
        hud.allowsCancelation = YES;
        hud.tag = TAG_HUD_COMPRESS;
    }
    hud.delegate = self;
    hud.labelText = NSLocalizedString(@"Compress", nil);
    
    [self.connectionManager compressFiles:files
                                toArchive:archive
                              archiveType:archiveType
                         compressionLevel:compressionLevel
                                 password:password
                                overwrite:overwrite];
}

#pragma mark - ExtractViewController delegate

- (void)extractFiles:(NSArray *)files
            toFolder:(FileItem *)folder
        withPassword:(NSString *)password
           overwrite:(BOOL)overwrite
   extractWithFolder:(BOOL)extractFolders
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                              animated:YES];
    if (ServerSupportsFeature(ExtractCancel))
    {
        hud.allowsCancelation = YES;
        hud.tag = TAG_HUD_EXTRACT;
    }
    hud.delegate = self;
    hud.labelText = NSLocalizedString(@"Extract", nil);
    
    [self.connectionManager extractFiles:files
                                toFolder:folder
                            withPassword:password
                               overwrite:overwrite
                       extractWithFolder:extractFolders];
}

#pragma mark - MoveFileViewController delegate

- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                              animated:YES];
    if (ServerSupportsFeature(MoveCancel))
    {
        hud.allowsCancelation = YES;
        hud.tag = TAG_HUD_MOVE;
    }
    hud.delegate = self;
    hud.labelText = NSLocalizedString(@"Move", nil);
 
    [self.connectionManager moveFiles:files
                               toPath:destFolder
                         andOverwrite:overwrite];
}

- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                              animated:YES];
    if (ServerSupportsFeature(CopyCancel))
    {
        hud.allowsCancelation = YES;
        hud.tag = TAG_HUD_COPY;
    }
    hud.delegate = self;
    hud.labelText = NSLocalizedString(@"Copy", nil);
    
	[self.connectionManager copyFiles:files
                               toPath:destFolder
                         andOverwrite:overwrite];
}

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder
{
    [self.connectionManager createFolder:folderName
                                  inFolder:folder];
}

#pragma mark - ShareViewController delegate

- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                              animated:YES];
    hud.delegate = self;
    hud.labelText = NSLocalizedString(@"Creating Shared links", nil);
    
    [self.connectionManager shareFiles:files duration:duration password:password];
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

#pragma mark - Keyboard notifications

- (void)keyboardWillShow:(NSNotification *)notification
{
    // When renaming a file, we need to prevent the keyboard from appearing over the name of the cell
    // So we change the inset when needed
    NSDictionary* info = [notification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    
    UIInterfaceOrientation orientation = (UIInterfaceOrientation)[[UIApplication sharedApplication] statusBarOrientation];
    UIEdgeInsets multipleSelectionTableContentInset;
    
	// Select the keyboard height
 	if (UIDeviceOrientationIsPortrait(orientation))
    {
        multipleSelectionTableContentInset = UIEdgeInsetsMake(0.0f, 0.0f, kbSize.height - 80.0f, 0.0f);
    }
    else
    {
        multipleSelectionTableContentInset = UIEdgeInsetsMake(0.0f, 0.0f, kbSize.width - 80.0f, 0.0f);
    }
    
    [self activeTableView].contentInset = multipleSelectionTableContentInset;
}

-(void) keyboardWillHide:(NSNotification *)notification
{
    UITableView *tableView = [self activeTableView];

	UIEdgeInsets multipleSelectionTableContentInset = UIEdgeInsetsZero;
    tableView.contentInset = multipleSelectionTableContentInset;
    tableView.scrollIndicatorInsets = multipleSelectionTableContentInset;
}

#pragma mark - ConnectionManager protocol

- (void)CMAction:(NSDictionary *)dict
{
    // If there is a message, show it
    if ([dict objectForKey:@"message"])
    {
        // Show error
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[dict objectForKey:@"title"]
														message:[dict objectForKey:@"message"]
													   delegate:nil
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
		[alert show];
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
        // Request ad
        [self requestAd];
        
        // Request list
        self.isConnected = TRUE;
        [self.connectionManager listForPath:self.currentFolder];
        [self.connectionManager spaceInfoAtPath:self.currentFolder];
    }
    else
    {
        // Remove any HUD
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        [hud hide:YES];
        
        // Show error
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Login",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:nil
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
		[alert show];
        
        // Go back to servers list
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

- (void)CMLogout:(NSDictionary *)dict
{
    if (self.isConnected)
    {
        self.isConnected = FALSE;
        [self.navigationController popViewControllerAnimated:YES];
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        [hud hide:YES];
    }
}

- (void)CMRequestOTP:(NSNotification *)notification
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"2-Factor Authentication",nil)
                                                    message:NSLocalizedString(@"Enter 6-digit code or 8-digit emergency code",nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel",nil)
                                          otherButtonTitles:NSLocalizedString(@"OK",nil),
                                                            NSLocalizedString(@"Request emergency code",nil),
                          nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = TAG_ALERT_OTP;
    [alert show];
}

- (void)CMFilesList:(NSDictionary *)dict
{
    [self.refreshControl endRefreshing];
    
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
            [self.multipleSelectionTableView performSelectorOnMainThread:@selector(reloadData)
                                                              withObject:nil
                                                           waitUntilDone:NO];
            // Update filtered results if needed
            [self updateFilteredResults];
        }
        else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Browse",nil)
                                                            message:NSLocalizedString([dict objectForKey:@"error"],nil)
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
            alert.tag = TAG_ALERT_DO_NOTHING;
            [alert show];
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

- (void)CMRename:(NSDictionary *)dict
{
	if ([[dict objectForKey:@"success"] boolValue] == NO)
    {
		// TODO : if it fails, restore the old name and paths instead of refreshing list
        
        // Update file list
        [self.connectionManager listForPath:self.currentFolder];
        
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File rename",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    else
    {
		// Refresh file list to refresh file type if needed
		[self.connectionManager listForPath:self.currentFolder];
    }
}

- (void)CMDeleteProgress:(NSDictionary *)dict
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    float progress = [[dict objectForKey:@"progress"] floatValue];
    if (progress != 0)
    {
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = progress;
    }
    if ([dict objectForKey:@"info"])
    {
        hud.detailsLabelText = [dict objectForKey:@"info"];
    }
}

- (void)CMDeleteFinished:(NSDictionary *)dict
{
	if ([[dict objectForKey:@"success"] boolValue] == NO)
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File delete",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
		
        // Update space information
        [self.connectionManager spaceInfoAtPath:self.currentFolder];
        
		// Get file list
		[self.connectionManager listForPath:self.currentFolder];
	}
    else
    {
        // Update space information
        [self.connectionManager spaceInfoAtPath:self.currentFolder];
        
        // Update filtered results if needed
        [self updateFilteredResults];
    }
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMCreateFolder:(NSDictionary *)dict
{
	if ([[dict objectForKey:@"success"] boolValue])
    {
		// Get file list
		[self.connectionManager listForPath:self.currentFolder];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Create folder",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
}

- (void)CMCopyProgress:(NSDictionary *)dict
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    float progress = [[dict objectForKey:@"progress"] floatValue];
    if (progress != 0)
    {
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = progress;
    }
    if ([dict objectForKey:@"info"])
    {
        hud.detailsLabelText = [dict objectForKey:@"info"];
    }
}

- (void)CMCopyFinished:(NSDictionary *)dict
{
	if ([[dict objectForKey:@"success"] boolValue])
    {
        // Update space information
        [self.connectionManager spaceInfoAtPath:self.currentFolder];
		// Get file list
		[self.connectionManager listForPath:self.currentFolder];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File copy",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMMoveProgress:(NSDictionary *)dict
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    float progress = [[dict objectForKey:@"progress"] floatValue];
    if (progress != 0)
    {
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = progress;
    }
    if ([dict objectForKey:@"info"])
    {
        hud.detailsLabelText = [dict objectForKey:@"info"];
    }
}

- (void)CMMoveFinished:(NSDictionary *)dict
{
	if ([[dict objectForKey:@"success"] boolValue])
    {
        // Update space information
        [self.connectionManager spaceInfoAtPath:self.currentFolder];
		// Get file list
		[self.connectionManager listForPath:self.currentFolder];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File move",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMEjectableList:(NSDictionary *)dict
{
	if ([[dict objectForKey:@"success"] boolValue])
    {
        for (NSDictionary *element in [dict objectForKey:@"ejectablelist"])
        {
            for (FileItem *item in self.filesArray)
            {
                if (item.isDir)
                {
                    if ([item.name isEqualToString:[element objectForKey:@"folder"]])
                    {
                        item.isEjectable = YES;
                        item.ejectName = [element objectForKey:@"ejectname"];
                    }
                }
            }
        }
    }
    [self.multipleSelectionTableView reloadData];
}

- (void)CMEjectFinished:(NSDictionary *)dict
{
	if ([[dict objectForKey:@"success"] boolValue])
    {
		// Get file list
		[self.connectionManager listForPath:self.currentFolder];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Eject",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMDownloadProgress:(NSDictionary *)dict
{
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
}

- (void)CMDownloadFinished:(NSDictionary *)dict
{
	if ([[dict objectForKey:@"success"] boolValue])
    {
        switch (self.downloadAction)
        {
            case DOWNLOAD_ACTION_SUBTITLE:
            {
                VLCMovieViewController *movieViewController = [[VLCMovieViewController alloc] initWithNibName:nil bundle:nil];
                
                movieViewController.url = self.videoNetworkConnection.url;
                movieViewController.pathToExternalSubtitlesFile = self.dlFilePath;
                
                UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:movieViewController];
                navCon.modalPresentationStyle = UIModalPresentationFullScreen;
                [self.navigationController presentViewController:navCon animated:YES completion:nil];
                break;
            }
            case DOWNLOAD_ACTION_PREVIEW:
            {
                FileItem *file = [[FileItem alloc] init];
                file.fullPath = self.dlFilePath;
                file.path = self.dlFilePath;
                file.name = self.sourceFileItem.name;
                file.type = self.sourceFileItem.type;
                file.isDir = NO;
                file.isCompressed = self.sourceFileItem.isCompressed;
                [self previewFile:file];
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
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File download",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}


- (void)CMUploadProgress:(NSDictionary *)dict
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    if ([dict objectForKey:@"progress"])
    {
        float progress = [[dict objectForKey:@"progress"] floatValue];
        if (progress != 0)
        {
            hud.mode = MBProgressHUDModeAnnularDeterminate;
            hud.progress = progress;
        }
        if ([dict objectForKey:@"uploadedBytes"])
        {
            NSNumber *uploaded = [dict objectForKey:@"uploadedBytes"];
            NSNumber *totalSize = [dict objectForKey:@"totalBytes"];
            hud.detailsLabelText = [NSString stringWithFormat:@"%@ of %@ done",[uploaded stringForNumberOfBytes],[totalSize stringForNumberOfBytes]];
        }
    }
    else
    {
        NSNumber *uploaded = [dict objectForKey:@"uploadedBytes"];
        hud.detailsLabelText = [NSString stringWithFormat:@"%@ done",[uploaded stringForNumberOfBytes]];
    }
}

- (void)CMUploadFinished:(NSDictionary *)dict
{
	if ([[dict objectForKey:@"success"] boolValue])
    {
		// Get file list
		[self.connectionManager listForPath:self.currentFolder];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File upload",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMCompressProgress:(NSDictionary *)dict
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    float progress = [[dict objectForKey:@"progress"] floatValue];
    if (progress != 0)
    {
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = progress;
    }

    NSNumber *done = [dict objectForKey:@"compressedBytes"];
    NSNumber *totalSize = [dict objectForKey:@"totalBytes"];
    if (([dict objectForKey:@"currentFile"]) && done && totalSize)
    {
        hud.labelText = [NSString stringWithFormat:NSLocalizedString(@"Compress %@",nil),[dict objectForKey:@"currentFile"]];
    }
    else if ([dict objectForKey:@"currentFile"])
    {
        hud.detailsLabelText = [dict objectForKey:@"currentFile"];
    }

    if (done && totalSize)
    {
        hud.detailsLabelText = [NSString stringWithFormat:@"%@ of %@ done",[done stringForNumberOfBytes],[totalSize stringForNumberOfBytes]];
    }
    
    if ([dict objectForKey:@"info"])
    {
        hud.detailsLabelText = [dict objectForKey:@"info"];
    }
}

- (void)CMCompressFinished:(NSDictionary *)dict
{
	if ([[dict objectForKey:@"success"] boolValue])
    {
        // Update list
		[self.connectionManager listForPath:self.currentFolder];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Compress",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMExtractProgress:(NSDictionary *)dict
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.progress = [[dict objectForKey:@"progress"] floatValue];
    NSNumber *done = [dict objectForKey:@"extractedBytes"];
    NSNumber *totalSize = [dict objectForKey:@"totalBytes"];
    if (([dict objectForKey:@"currentFile"]) && done && totalSize)
    {
        hud.labelText = [NSString stringWithFormat:NSLocalizedString(@"Extract %@",nil),[dict objectForKey:@"currentFile"]];
    }
    else if ([dict objectForKey:@"currentFile"])
    {
        hud.detailsLabelText = [dict objectForKey:@"currentFile"];
    }
    
    if (done && totalSize)
    {
        hud.detailsLabelText = [NSString stringWithFormat:@"%@ of %@ done",[done stringForNumberOfBytes],[totalSize stringForNumberOfBytes]];
    }
    
    if ([dict objectForKey:@"info"])
    {
        hud.detailsLabelText = [dict objectForKey:@"info"];
    }

}

- (void)CMExtractFinished:(NSDictionary *)dict
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
    
	if ([[dict objectForKey:@"success"] boolValue])
    {
        // Update list
        [self.connectionManager listForPath:self.currentFolder];
        // Update space information
        [self.connectionManager spaceInfoAtPath:self.currentFolder];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Extract",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
}

- (void)CMSearchFinished:(NSDictionary *)dict
{
    self.searchBarPlaceholderText.text = NSLocalizedString(@"No Results", nil);

    // Check if we are still in the server search view
    if ((self.searchDisplayController.active) &&
        ([self.searchDisplayController.searchBar selectedScopeButtonIndex] == SEARCH_SCOPE_RECURSIVE))
    {
        NSArray *filesList = [dict objectForKey:@"filesList"];
        [self.filteredFilesArray removeAllObjects];
        
        int i;
        for (i=0; i<[filesList count]; i++)
        {
            FileItem *fileItem = [[FileItem alloc] init];
            fileItem.name = [[filesList objectAtIndex:i] objectForKey:@"filename"];
            fileItem.isDir = [[[filesList objectAtIndex:i] objectForKey:@"isdir"] boolValue];
            fileItem.shortPath = [[[filesList objectAtIndex:i] objectForKey:@"path"] stringByDeletingLastPathComponent];
            fileItem.path = [[filesList objectAtIndex:i] objectForKey:@"path"];
            
            if ([[filesList objectAtIndex:i] objectForKey:@"fullpath"])
            {
                fileItem.fullPath = [[filesList objectAtIndex:i] objectForKey:@"fullpath"];
            }
            else
            {
                fileItem.fullPath = fileItem.path;
            }
            
            fileItem.isCompressed = [[[filesList objectAtIndex:i] objectForKey:@"iscompressed"] boolValue];
            
            if (fileItem.isDir)
            {
                fileItem.fileSize = nil;
                fileItem.fileSizeNumber = nil;
                fileItem.owner = [[filesList objectAtIndex:i] objectForKey:@"owner"];
                if ([[filesList objectAtIndex:i] objectForKey:@"isejectable"])
                {
                    fileItem.isEjectable = [[[filesList objectAtIndex:i] objectForKey:@"isejectable"] boolValue];
                }
                else
                {
                    fileItem.isEjectable = NO;
                }
            }
            else
            {
                if ([[filesList objectAtIndex:i] objectForKey:@"type"])
                {
                    fileItem.type = [[filesList objectAtIndex:i] objectForKey:@"type"];
                }
                else
                {
                    fileItem.type = [[fileItem.name componentsSeparatedByString:@"."] lastObject];
                }
                
                if ([[filesList objectAtIndex:i] objectForKey:@"filesizenumber"])
                {
                    fileItem.fileSizeNumber = [[filesList objectAtIndex:i] objectForKey:@"filesizenumber"];
                }
                else
                {
                    fileItem.fileSizeNumber = nil;
                }
                fileItem.fileSize = [[[filesList objectAtIndex:i] objectForKey:@"filesizenumber"] stringForNumberOfBytes];
                
                fileItem.owner = [[filesList objectAtIndex:i] objectForKey:@"owner"];
                
                fileItem.isEjectable = NO;
            }
            fileItem.writeAccess = [[[filesList objectAtIndex:i] objectForKey:@"writeaccess"] boolValue];
            
            /* Date */
            if ([[filesList objectAtIndex:i] objectForKey:@"date"])
            {
                fileItem.fileDateNumber = [NSNumber numberWithDouble:[[[filesList objectAtIndex:i] objectForKey:@"date"] doubleValue]];
                NSTimeInterval mtime = (NSTimeInterval)[[[filesList objectAtIndex:i] objectForKey:@"date"] doubleValue];
                NSDate *mdate = [NSDate dateWithTimeIntervalSince1970:mtime];
                NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
                [formatter setDateStyle:NSDateFormatterMediumStyle];
                [formatter setTimeStyle:NSDateFormatterShortStyle];
                
                fileItem.fileDate = [formatter stringFromDate:mdate];
            }

            if ([[filesList objectAtIndex:i] objectForKey:@"id"])
            {
                fileItem.objectIds = [self.currentFolder.objectIds arrayByAddingObject:[[filesList objectAtIndex:i] objectForKey:@"id"]];
            }
            
            /* DownloadURL */
            if ([[filesList objectAtIndex:i] objectForKey:@"url"])
            {
                fileItem.downloadUrl = [[filesList objectAtIndex:i] objectForKey:@"url"];
            }
            [self.filteredFilesArray addObject:fileItem];
        }
        
        // Sort files array
        [self.filteredFilesArray sortFileItemArrayWithOrder:self.sortingType];
        
        // Refresh tableView
        [[self.searchDisplayController searchResultsTableView] performSelectorOnMainThread:@selector(reloadData)
                                                                                withObject:nil
                                                                             waitUntilDone:NO];
    }
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMShareProgress:(NSDictionary *)dict
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    float progress = [[dict objectForKey:@"progress"] floatValue];
    if (progress != 0)
    {
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = progress;
    }
    if ([dict objectForKey:@"info"])
    {
        hud.detailsLabelText = [dict objectForKey:@"info"];
    }
}

- (void)CMShareFinished:(NSDictionary *)dict
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
    
	if ([[dict objectForKey:@"success"] boolValue])
    {
        // Show menu to share link(s)
        NSMutableString *shares = [dict objectForKey:@"shares"];
        [shares appendString:NSLocalizedString(@"\r\nShared using NAStify for iPhone/iPad http://nastify.codeisalie.com\r\n",nil)];

        NSArray *objectsToShare = [NSArray arrayWithObject:shares];
        
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
        
        [self presentViewController:activityViewController
                           animated:YES
                         completion:nil];
    }
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Creating Shared links",nil)
														message:NSLocalizedString([dict objectForKey:@"error"],nil)
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
}

- (void)CMConnectionError:(NSDictionary *)dict
{
    // We should hide HUD if any ...
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
    
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Connection error",nil)
													message:NSLocalizedString([dict objectForKey:@"error"],nil)
												   delegate:self
										  cancelButtonTitle:nil
										  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
    alert.tag = TAG_ALERT_DO_NOTHING;
	[alert show];
}

#pragma mark - UISearchDisplayController Delegate Methods

- (void)updateFilteredResults
{
    if ((self.searchDisplayController.active) && ([self.searchDisplayController.searchBar selectedScopeButtonIndex] == SEARCH_SCOPE_FOLDER))
    {
        // Update the current search
        [self.filteredFilesArray removeAllObjects];
        
        for (FileItem *file in self.filesArray)
        {
            NSRange range = [file.name rangeOfString:self.searchDisplayController.searchBar.text
                                             options:(NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch)];
            if (range.location != NSNotFound)
            {
                [self.filteredFilesArray addObject:file];
            }
        }
        // Refresh tableView
        [self.searchDisplayController.searchResultsTableView performSelectorOnMainThread:@selector(reloadData)
                                                                              withObject:nil
                                                                           waitUntilDone:NO];
    }
}

- (void)searchDisplayController:(UISearchDisplayController *)controller willShowSearchResultsTableView:(UITableView *)tableView
{
    // Quit edit mode for main table
    if ([self activeTableView].isEditing)
    {
        [self toggleEditButton];
    }
    else
    {
        [self.selectedIndexes removeAllIndexes];
    }
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView
{
    tableView.rowHeight = TABLE_ROW_HEIGHT;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.filteredFilesArray removeAllObjects];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    // Hack to get the UISearchDisplayController "No Result" UILabel
    if (!self.searchBarPlaceholderText)
    {
        for (UIView* v in self.searchDisplayController.searchResultsTableView.subviews) {
            if ([v isKindOfClass: [UILabel class]])
            {
                self.searchBarPlaceholderText = (UILabel *)v;
                break;
            }
        }
    }
    
    switch ([self.searchDisplayController.searchBar selectedScopeButtonIndex])
    {
        case SEARCH_SCOPE_FOLDER:
        {
            self.searchBarPlaceholderText.text = NSLocalizedString(@"No Results", nil);
            [self.filteredFilesArray removeAllObjects];
            
            for (FileItem *file in self.filesArray)
            {
                NSRange range = [file.name rangeOfString:searchString
                                                 options:(NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch)];
                if (range.location != NSNotFound)
                {
                    [self.filteredFilesArray addObject:file];
                }
            }
            break;
        }
        case SEARCH_SCOPE_RECURSIVE:
        {
            // Clear previous info
            [self.filteredFilesArray removeAllObjects];
            self.searchBarPlaceholderText.text = NSLocalizedString(@"Press search to get results", nil);
            break;
        }
        default:
            break;
    }
    
    // Reset selected elements
    if (self.searchDisplayController.searchResultsTableView.isEditing)
    {
        [self.selectedIndexes removeAllIndexes];
        [self updateActionBar];
    }

    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    switch ([self.searchDisplayController.searchBar selectedScopeButtonIndex])
    {
        case SEARCH_SCOPE_FOLDER:
        {
            self.searchBarPlaceholderText.text = NSLocalizedString(@"No Results", nil);
            [self.filteredFilesArray removeAllObjects];
            
            for (FileItem *file in self.filesArray)
            {
                NSRange range = [file.name rangeOfString:self.searchDisplayController.searchBar.text
                                                 options:(NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch)];
                if (range.location != NSNotFound)
                {
                    [self.filteredFilesArray addObject:file];
                }
            }
            break;
        }
        case SEARCH_SCOPE_RECURSIVE:
        {
            self.searchBarPlaceholderText.text = NSLocalizedString(@"Press search to get results", nil);
            [self.filteredFilesArray removeAllObjects];
            if ([self.searchDisplayController.searchBar.text length] != 0)
            {
                [self.searchBar resignFirstResponder];

                MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                          animated:YES];
                if (ServerSupportsFeature(SearchCancel))
                {
                    hud.allowsCancelation = YES;
                    hud.tag = TAG_HUD_SEARCH;
                }
                hud.delegate = self;
                hud.labelText = NSLocalizedString(@"Searching", nil);
                
                [self.connectionManager searchFiles:self.searchDisplayController.searchBar.text atPath:self.currentFolder];
            }
            break;
        }
        default:
            break;
    }
    
    // Return YES to cause the search result table view to be reloaded.
    return YES;
}

- (void)searchDisplayControllerDidBeginSearch:(UISearchDisplayController *)controller
{
}

#pragma mark - UISearchBar Delegate Methods

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    if (self.searchDisplayController.searchResultsTableView.isEditing)
    {
        [self toggleEditButton];
    }
    else
    {
        [self.selectedIndexes removeAllIndexes];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    if (([self.searchDisplayController.searchBar selectedScopeButtonIndex] == SEARCH_SCOPE_RECURSIVE) &&
        ([self.searchDisplayController.searchBar.text length] != 0))
    {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                  animated:YES];
        if (ServerSupportsFeature(SearchCancel))
        {
            hud.allowsCancelation = YES;
            hud.tag = TAG_HUD_SEARCH;
        }
        hud.delegate = self;
        hud.labelText = NSLocalizedString(@"Searching", nil);

        [self.connectionManager searchFiles:self.searchDisplayController.searchBar.text atPath:self.currentFolder];
    }
}

#pragma mark - Orientation management

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation
{
    return YES;
}

#pragma mark - Item action sheet

- (void)showActionMenuForItemAtIndexPath:(NSIndexPath *)indexpath
{
    NSMutableArray *sourceArray = nil;
    UITableView *tableView = [self activeTableView];
    if (self.searchDisplayController.active)
    {
        sourceArray = self.filteredFilesArray;
    }
    else
    {
        sourceArray = self.filesArray;
    }
    
    FileBrowserCell *aCell = (FileBrowserCell *)[tableView cellForRowAtIndexPath:indexpath];
    
    FileItem *fileItem = (FileItem *)([sourceArray objectAtIndex:indexpath.row]);
    
    self.itemActionSheet = [[UIActionSheet alloc] initWithTitle:fileItem.name
                                                          delegate:self
                                                 cancelButtonTitle:nil
                                            destructiveButtonTitle:nil
                                                 otherButtonTitles:nil];
    self.itemActionSheet.actionSheetStyle = UIActionSheetStyleDefault;
    
    if ((ServerSupportsFeature(Eject)) && (fileItem.isEjectable))
    {
        self.ejectButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Eject",nil)];
    }
    else
    {
        self.ejectButtonIndex = -1;
    }

    if ((fileItem.writeAccess) &&
        (
         (!fileItem.isDir && (ServerSupportsFeature(FileDelete))) ||
         (fileItem.isDir && (ServerSupportsFeature(FolderDelete)))
         )
        )
    {
        self.itemActionSheet.destructiveButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Delete",nil)];
    }
    else
    {
        self.itemActionSheet.destructiveButtonIndex = -1;
    }
    
    if ((self.userAccount.serverType != SERVER_TYPE_LOCAL) && (fileItem.fileType != FILETYPE_UNKNOWN))
    {
        self.previewButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Preview",nil)];
    }
    else
    {
        self.previewButtonIndex = -1;
    }
    
    if ((!fileItem.isDir && (ServerSupportsFeature(FileRename))) ||
        (fileItem.isDir && (ServerSupportsFeature(FolderRename))))
    {
        self.renameButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Rename",nil)];
    }
    else
    {
        self.renameButtonIndex = -1;
    }
    
    if (
        (!fileItem.isDir && ((ServerSupportsFeature(FileCopy)) || (ServerSupportsFeature(FileMove)))) ||
        (fileItem.isDir && ((ServerSupportsFeature(FolderCopy)) || (ServerSupportsFeature(FolderMove))))
        )
    {
        self.moveCopyButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Copy/Move",nil)];
    }
    else
    {
        self.moveCopyButtonIndex = -1;
    }
    
    if (ServerSupportsFeature(Compress))
    {
        self.compressButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Compress",nil)];
    }
    else
    {
        self.compressButtonIndex = -1;
    }
    
    if (fileItem.isCompressed)
    {
        self.extractButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Extract",nil)];
    }
    else
    {
        self.extractButtonIndex = -1;
    }
    
    if (((ServerSupportsFeature(FileShare)) && (!fileItem.isDir)) ||
        ((ServerSupportsFeature(FolderShare)) && (fileItem.isDir)))
    {
        self.shareButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Share",nil)];
    }
    else
    {
        self.shareButtonIndex = -1;
    }
    
    if ((ServerSupportsFeature(OpenIn)) && (!fileItem.isDir))
    {
        self.openInButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Open in...",nil)];
    }
    else
    {
        self.openInButtonIndex = -1;
    }
    
    if ((ServerSupportsFeature(FileDownload)) && (!fileItem.isDir) && (self.userAccount.serverType != SERVER_TYPE_LOCAL))
    {
        self.downloadButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Download locally",nil)];
    }
    else
    {
        self.downloadButtonIndex = -1;
    }

    self.itemActionSheet.tag = indexpath.row;
    
    if (self.itemActionSheet.numberOfButtons != 0)
    {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            self.itemActionSheet.cancelButtonIndex = -1;
            
            [self.itemActionSheet showFromRect:aCell.bounds
                                           inView:aCell.contentView
                                         animated:YES];
        }
        else
        {
            self.itemActionSheet.cancelButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Cancel",nil)];
            [self.itemActionSheet showInView:self.parentViewController.tabBarController.view];
        }
    }
}

#pragma mark - Sorting option management

- (void)selectedSortingType:(FileItemSortType)sortingType
{
    if (self.sortPopoverController.isPopoverVisible)
    {
        [self.sortPopoverController dismissPopoverAnimated:YES];
        self.sortPopoverController = nil;
    }

    self.sortingType = sortingType;
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    [defaults setInteger:sortingType forKey:@"sortingType"];
    [defaults synchronize];
    
    [self.filesArray sortFileItemArrayWithOrder:self.sortingType];
    [self.multipleSelectionTableView reloadData];
}

- (void)cancelSortingType
{
    if (self.sortPopoverController.isPopoverVisible)
    {
        [self.sortPopoverController dismissPopoverAnimated:YES];
        self.sortPopoverController = nil;
    }
}

#pragma mark - Multiple files extract management

- (BOOL)selectedFilesCanBeExtracted
{
    BOOL canBeExtracted = YES;
    NSMutableArray *sourceArray = nil;
    if (self.searchDisplayController.active)
    {
        sourceArray = self.filteredFilesArray;
    }
    else
    {
        sourceArray = self.filesArray;
    }
    
    NSUInteger current_index = [self.selectedIndexes firstIndex];
    while (current_index != NSNotFound)
    {
        FileItem *fileItem = (FileItem *)([sourceArray objectAtIndex:current_index]);
        if (!fileItem.isCompressed)
        {
            canBeExtracted = NO;
            break;
        }
        current_index = [self.selectedIndexes indexGreaterThanIndex: current_index];
    }
    return canBeExtracted;
}

#pragma mark - GoogleCast support
- (void)updateGCState
{
    [self updateBarButtons];
}

- (void)didDiscoverDeviceOnNetwork
{
    [self updateBarButtons];
}

- (void)chooseDevice:(id)sender
{
    //Choose device
    if (_gcController.selectedDevice == nil)
    {
        //Choose device
        _gcActionSheet =
        [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Connect to Device", nil)
                                    delegate:self
                           cancelButtonTitle:nil
                      destructiveButtonTitle:nil
                           otherButtonTitles:nil];
        
        for (GCKDevice *device in _gcController.deviceScanner.devices)
        {
            [_gcActionSheet addButtonWithTitle:device.friendlyName];
        }
        
        [_gcActionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        _gcActionSheet.cancelButtonIndex = _gcActionSheet.numberOfButtons - 1;
        
        //show device selection
        [_gcActionSheet showInView:_chromecastButton];
    }
    else
    {
        // Gather stats from device.
        [_gcController updateStatsFromDevice];
        
        NSString *friendlyName = [NSString stringWithFormat:NSLocalizedString(@"Casting to %@", nil),
                                  _gcController.selectedDevice.friendlyName];
        NSString *mediaTitle = [_gcController.mediaInformation.metadata stringForKey:kGCKMetadataKeyTitle];
        
        _gcActionSheet = [[UIActionSheet alloc] init];
        _gcActionSheet.title = friendlyName;
        _gcActionSheet.delegate = self;
        if (mediaTitle != nil)
        {
            [_gcActionSheet addButtonWithTitle:mediaTitle];
        }
        
        //Offer disconnect option
        _gcActionSheet.destructiveButtonIndex = [_gcActionSheet addButtonWithTitle:@"Disconnect"];
        _gcActionSheet.cancelButtonIndex = [_gcActionSheet addButtonWithTitle:@"Cancel"];
        
        [_gcActionSheet showInView:_chromecastButton];
    }
}

#pragma mark - Ad Management

- (void)requestAd
{
    if (([self.userAccount shouldShowAds]) &&
        ([self.currentFolder.path isEqual:@"/"]))
    {
        if (![self requestInterstitialAdPresentation])
        {
            NSLog(@"fallback to Google Ads");
            GADRequest *request = [GADRequest request];
            request.testDevices = [NSArray arrayWithObjects:GAD_SIMULATOR_ID, IPHONE5S_ID, nil];
            
            if (self.interstitial == nil)
            {
                self.interstitial = [[GADInterstitial alloc] init];
                self.interstitial.adUnitID = NASTIFY_FULL_SCREEN_INTERSTITIAL_ID;
                self.interstitial.delegate = self;
            }
            
            [self.interstitial loadRequest:request];
        }
    }
}

#pragma mark - GADInterstitialDelegate

- (void)interstitialDidReceiveAd:(GADInterstitial *)ad
{
    NSLog(@"interstitialDidReceiveAd");
    [ad presentFromRootViewController:self];
}

- (void)interstitial:(GADInterstitial *)ad didFailToReceiveAdWithError:(GADRequestError *)error
{
    NSLog(@"interstitial didFailToReceiveAdWithError");
}

#pragma mark - Memory management

- (void)dealloc
{
    // To fix "-[UIView release]: message sent to deallocated instance xxxxx"
    self.multipleSelectionTableView.tableHeaderView = nil;
    [self.searchBar removeFromSuperview];
    self.searchBar = nil;
    self.searchDisplayController = nil;
}

@end
