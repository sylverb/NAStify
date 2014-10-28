//
//  FileBrowserViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//
//  TODO : add a way to request password to the user at login only (not saved in server's setting)
//  TODO : Present a menu to select sorting options
//  TODO : use some icons (for copy/move/delete/invert selection) instead of text if we can mix icons with text description for voiceover (for blind people)
//  TODO : Add more file viewers (photo,txt,docx,xlsx,pptx, ...)
//  TODO : add something to explain to the user how to use the application (long tap on file for options)
//  TODO : add PhotoLibrary upload feature
//  TODO : allow to cancel copy/move/delete/extract/compress if possible

#import "FileBrowserViewController.h"
#import "CustomNavigationController.h"
#import "CustomTabBarController.h"
#import "FileItem.h"

#import "ExtractViewController.h"
#import "CompressViewController.h"
#import "SortItemsViewController.h"

// File viewers
#import "CustomMoviePlayerViewController.h"
#import "MVLCMovieViewController.h"
// Additions
#import "NSNumberAdditions.h"

@interface FileBrowserViewController (Private)
- (void)longPressAction:(UILongPressGestureRecognizer*)longPressRecognizer;
- (void)toggleEditButton;
- (void)showActionMenuForItemAtIndexPath:(NSIndexPath *)indexpath;
@end

#define TAG_HUD_DOWNLOAD    1
#define TAG_HUD_COPY        2
#define TAG_HUD_MOVE        3
#define TAG_HUD_EXTRACT     4
#define TAG_HUD_COMPRESS    5
#define TAG_HUD_DELETE      6
#define TAG_HUD_UPLOAD      7

@interface FileBrowserViewController ()

@end

@implementation FileBrowserViewController

- (id)init
{
    self = [super init];
    if (self)
    {
        self.selectedIndexes = [[NSMutableIndexSet alloc] init];
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Setup tableView
    self.multipleSelectionTableView = [[UITableView alloc] initWithFrame:[[self view] bounds] style:UITableViewStylePlain];
	[self.multipleSelectionTableView setDelegate:self];
	[self.multipleSelectionTableView setDataSource:self];
	[self.multipleSelectionTableView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    self.multipleSelectionTableView.backgroundColor = [UIColor clearColor];
    self.multipleSelectionTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.multipleSelectionTableView.rowHeight = 50.0;
    self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];

    [self.view addSubview:self.multipleSelectionTableView];
    
    NSString *title = [[self.serverPath componentsSeparatedByString:@"/"] lastObject];
	if ([title length] == 0)
    {
		title = @"/";
	}
    
    self.navigationItem.title = title;
    UIBarButtonItem *editButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                    target:self
                                                                                    action:@selector(toggleEditButton)];
    UIBarButtonItem *actionButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                    target:self
                                                                                      action:@selector(actionButton:)];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:
                                               editButtonItem,
                                               actionButtonItem,
                                               nil] ;
    
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [self.navigationController.toolbar setTintColor:[UIColor blackColor]];

    self.refreshControl = [[ODRefreshControl alloc] initInScrollView:self.multipleSelectionTableView];
    self.refreshControl.backgroundColor = [UIColor clearColor];
    [self.refreshControl addTarget:self action:@selector(dropViewDidBeginRefreshing:) forControlEvents:UIControlEventValueChanged];
}

- (void)dropViewDidBeginRefreshing:(ODRefreshControl *)refreshControl
{
    [self.connectionManager listForPath:self.serverPath];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (!self.connectionManager)
    {
        self.connectionManager = [[ConnectionManager alloc] init];
        self.connectionManager.userAccount = self.userAccount;
    }
    [self.connectionManager addObserver:self];
    
#warning to remove when vlc player will be ok
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
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
    }
    // Show tab bar if it was not visible
    [(CustomTabBarController *)self.tabBarController setTabBarHidden:NO withAnimation:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
	if ([self.serverPath isEqualToString:@"/"])
    {
		if (([self.filesArray count] == 0))
        {
            // Login
            BOOL needToWaitLogin = NO;
            needToWaitLogin = [self.connectionManager login];
            
			// Get file list if possible
            if (!needToWaitLogin)
            {
                [self.connectionManager listForPath:self.serverPath];
                [self.connectionManager spaceInfoAtPath:self.serverPath];
            }
        }
        else if (self.userAccount == nil)
        {
            // Get file list
            [self.connectionManager listForPath:self.serverPath];
            [self.connectionManager spaceInfoAtPath:self.serverPath];
        }
	}
    else if ([self.filesArray count] == 0)
    {
		// Get file list
		[self.connectionManager listForPath:self.serverPath];
        [self.connectionManager spaceInfoAtPath:self.serverPath];
	}
    else if (self.userAccount == nil)
    {
		// Get file list (we are with local files, it costs nothing to reload here)
		[self.connectionManager listForPath:self.serverPath];
        [self.connectionManager spaceInfoAtPath:self.serverPath];
    }
    
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.connectionManager removeObserver:self];

    if ([self.serverPath isEqualToString:@"/"])
    {
        // We are leaving the root folder, check if we have to logout from server
        NSArray *viewControllers = self.navigationController.viewControllers;
        if ((viewControllers.count > 1) &&
            ([viewControllers objectAtIndex:viewControllers.count-2] == self))
        {
            // We are pushing a new view, nothing to do
        }
        else if (![viewControllers containsObject:self])
        {
            // We are going back to servers list, logout from server
            [self.connectionManager logout];
        }
    }
    
    // Hide toolbar if needed
    if (self.multipleSelectionTableView.isEditing)
    {
        [self toggleEditButton];
    }
    
    [super viewWillDisappear:animated];

}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

#pragma mark - MoveFileViewControllerDelegate

- (void)backFromModalView
{
    // On iPad, viewWillAppear is not called if modalPresentationStyle = UIModalPresentationFormSheet
    // as view didn't desappear (but we removed observer when we did push the view)
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        [self.connectionManager addObserver:self];
        if (self.userAccount == nil)
        {
            // Get file list (we are with local files, it costs nothing to reload here)
            [self.connectionManager listForPath:self.serverPath];
            [self.connectionManager spaceInfoAtPath:self.serverPath];
        }
    }
}

#pragma mark - button actions

- (void)toggleEditButton
{
    if (self.multipleSelectionTableView.isEditing)
    {
        [self.multipleSelectionTableView setAllowsMultipleSelectionDuringEditing:NO];
        [self.multipleSelectionTableView setEditing:NO animated:YES];
        
        UIBarButtonItem *editButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                        target:self
                                                                                        action:@selector(toggleEditButton)];
        UIBarButtonItem *actionButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                          target:self
                                                                                          action:@selector(actionButton:)];

        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:
                                                   editButtonItem,
                                                   actionButtonItem,
                                                   nil] ;
        
        [self.selectedIndexes removeAllIndexes];
        [self.navigationController setToolbarHidden:YES animated:YES];
        
        // Enable pull to refresh
        self.refreshControl.enabled = YES;
        
        /* Restore long tap handling (was removed when entered edit mode) */
        NSInteger rows = [self.multipleSelectionTableView numberOfRowsInSection:0];
        NSInteger index;
        for (index = 0; index < rows; index++)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            UITableViewCell *oneCell = [self.multipleSelectionTableView cellForRowAtIndexPath:indexPath];
            
            // Long tap recognizer
            UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                              action:@selector(longPressAction:)];
            [oneCell addGestureRecognizer:longPressRecognizer];
        }
        
        // Enable pressing on back button
        [self.navigationItem setHidesBackButton:NO animated:YES];
    }
    else
    {
        // Disable pull to refresh
        self.refreshControl.enabled = NO;

        // Disable pressing back button
        [self.navigationItem setHidesBackButton:YES animated:YES];
        
        // Enter edit mode
        [self.multipleSelectionTableView setAllowsMultipleSelectionDuringEditing:YES];
        [self.multipleSelectionTableView setEditing:YES animated:YES];
        
        /* Remove long tap handling (need to be restored at the end of renaming) */
        NSInteger rows = [self.multipleSelectionTableView numberOfRowsInSection:0];
        NSInteger index;
        for (index = 0; index < rows; index++)
        {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            UITableViewCell *oneCell = [self.multipleSelectionTableView cellForRowAtIndexPath:indexPath];
            
            NSArray *gestureList = [oneCell gestureRecognizers];
            for (id gesture in gestureList) {
                if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]]) {
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
                                                                              style:UIBarButtonItemStyleBordered
                                                                             target:self
                                                                             action:@selector(deleteFilesButton:event:)];
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
            
            if (self.moveCopyFilesButtonItem) {
                self.moveCopyFilesButtonItem.title = NSLocalizedString(@"Copy/Move",nil);
            } else {
                self.moveCopyFilesButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Copy/Move",nil)
                                                                                style:UIBarButtonItemStyleBordered
                                                                               target:self
                                                                               action:@selector(copyMoveFilesButton:event:)];
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
                                                                                style:UIBarButtonItemStyleBordered
                                                                               target:self
                                                                               action:@selector(compressFilesButton:event:)];
            }
            [self.compressFilesButtonItem setEnabled:NO];
            [buttons addObject:self.compressFilesButtonItem];
        }
        
        [buttons addObject:flexibleSpaceButtonItem];
        if (self.invertSelectionButtonItem == nil)
        {
            self.invertSelectionButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Invert",nil)
                                                                         style:UIBarButtonItemStyleBordered
                                                                        target:self
                                                                        action:@selector(invertSelectionButton:event:)];
        }
        [buttons addObject:self.invertSelectionButtonItem];

        [buttons addObject:flexibleSpaceButtonItem];
        
        [self setToolbarItems:buttons];
        [self.navigationController setToolbarHidden:NO animated:YES];
    }
}

- (void)deleteFilesButton:(UIBarButtonItem*)sender event:(UIEvent*)event {
    if ([self.selectedIndexes count] == 0) {
        return;
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Delete files",@"")
                                                    message:[NSString stringWithFormat:NSLocalizedString(@"delete %d files ?",nil),[self.selectedIndexes count]]
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel",@"")
                                          otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
    alert.tag = 0;
    [alert show];
}

- (void)copyMoveFilesButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    if ([self.selectedIndexes count] == 0)
    {
        return;
    }
    
    NSMutableArray *fileItems = [NSMutableArray array];
    NSUInteger current_index = [self.selectedIndexes firstIndex];
    while (current_index != NSNotFound)
    {
        FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:current_index]);
        [fileItems addObject:fileItem];
        
        current_index = [self.selectedIndexes indexGreaterThanIndex: current_index];
    }
    
    // on iPad, presenting FormSheet will not make current view disappear, unregister notifications manually
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad))
    {
        [self.connectionManager removeObserver:self];
    }
    
    [self toggleEditButton];

    // Push all needed views
    NSArray *pathArray = [self.serverPath componentsSeparatedByString:@"/"];
    NSString *path = @"/";
    
    CustomNavigationController *moveNavController = [[CustomNavigationController alloc] init];
    moveNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    for (NSString *pathComponent in pathArray)
    {
        path = [path stringByAppendingPathComponent:pathComponent];
        // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
        // even with UIModalPresentationFormSheet (not the default behavior)
        MoveFileViewController *moveFileViewController = [[MoveFileViewController alloc] initWithPath:path
                                                                                           sourcePath:self.serverPath
                                                                                             andFiles:fileItems];
        moveFileViewController.title = path;
        moveFileViewController.delegate = self;
        moveFileViewController.connectionManager = self.connectionManager;
        [moveNavController pushViewController:moveFileViewController animated:NO];
    }
    [self.navigationController presentModalViewController:moveNavController animated:YES];
}

- (void)compressFilesButton:(UIBarButtonItem*)sender event:(UIEvent*)event {
    if ([self.selectedIndexes count] == 0) {
        return;
    }
    
    NSMutableArray *fileItems = [NSMutableArray array];
    NSUInteger current_index = [self.selectedIndexes firstIndex];
    while (current_index != NSNotFound)
    {
        FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:current_index]);
        [fileItems addObject:fileItem];
        
        current_index = [self.selectedIndexes indexGreaterThanIndex: current_index];
    }

    [self toggleEditButton];

    // on iPad, presenting FormSheet will not make current view disappear, unregister notifications manually
    if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad))
    {
        [self.connectionManager removeObserver:self];
    }

    NSString *archiveName = nil;
    if ([fileItems count] == 1)
    {
        archiveName = [((FileItem *)[fileItems objectAtIndex:0]).name stringByAppendingString:@".zip"];
    }
    else
    {
        if ([self.serverPath isEqualToString:@"/"])
        {
            archiveName = @"archive.zip";
        }
        else
        {
            archiveName = [[[self.serverPath componentsSeparatedByString:@"/"] lastObject] stringByAppendingString:@".zip"];
        }
    }
    // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
    // even with UIModalPresentationFormSheet (not the default behavior)
    CompressViewController *compressViewController = [[CompressViewController alloc] init];
    compressViewController.connectionManager = self.connectionManager;
    compressViewController.files = fileItems;
    compressViewController.atPath = self.serverPath;
    compressViewController.destDir = self.serverPath;
    compressViewController.destArchive = archiveName;
    compressViewController.delegate = self;
    CustomNavigationController *extractNavController = [[CustomNavigationController alloc] initWithRootViewController:compressViewController];
    extractNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.navigationController presentModalViewController:extractNavController animated:YES];
}

- (void)invertSelectionButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    NSInteger index;
    for (index = 0; index < [self.filesArray count]; index++)
    {
        NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:0];
        if ([self.selectedIndexes containsIndex:index])
        {
            [self.selectedIndexes removeIndex:index];
            [self.multipleSelectionTableView deselectRowAtIndexPath:path animated:YES];
        }
        else
        {
            [self.selectedIndexes addIndex:index];
            [self.multipleSelectionTableView selectRowAtIndexPath:path animated:YES scrollPosition:UITableViewScrollPositionNone];
        }
    }
    
    // Update labels for count
    if ([self.selectedIndexes count] == 0) {
        self.deleteFilesButtonItem.title = NSLocalizedString(@"Delete",nil);
        [self.deleteFilesButtonItem setEnabled:NO];
        self.moveCopyFilesButtonItem.title = NSLocalizedString(@"Copy/Move",nil);
        [self.moveCopyFilesButtonItem setEnabled:NO];
        self.compressFilesButtonItem.title = NSLocalizedString(@"Compress",nil);
        [self.compressFilesButtonItem setEnabled:NO];
    } else {
        self.deleteFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Delete (%d)",nil),[self.selectedIndexes count]];
        [self.deleteFilesButtonItem setEnabled:YES];
        self.moveCopyFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Copy/Move (%d)",nil),[self.selectedIndexes count]];
        [self.moveCopyFilesButtonItem setEnabled:YES];
        self.compressFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Compress (%d)",nil),[self.selectedIndexes count]];
        [self.compressFilesButtonItem setEnabled:YES];
    }
}

- (void)actionButton:(UIBarButtonItem *)button
{
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
        
        self.sortItemsActionButtonIndex = [self.actionSheet addButtonWithTitle:NSLocalizedString(@"Sort files",nil)];;
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            self.actionSheet.cancelButtonIndex = -1;
            
            [self.actionSheet showFromBarButtonItem:button
                                           animated:YES];
        }
        else
        {
            self.actionSheet.cancelButtonIndex = [self.actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel",@"")];
            
            [self.actionSheet showInView:self.parentViewController.tabBarController.view];
        }
    }
}

#pragma mark - Table view data source

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
    
	FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);
    
	FileBrowserCell *fileBrowserCell = (FileBrowserCell *)[tableView dequeueReusableCellWithIdentifier:FileBrowserCellIdentifier];
	if (fileBrowserCell == nil)
    {
		fileBrowserCell = [[FileBrowserCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                 reuseIdentifier:FileBrowserCellIdentifier];
	}
    
    // Remove long tap gesture recognizer if present
    NSArray *gestureList = [fileBrowserCell gestureRecognizers];
    for (id gesture in gestureList) {
        if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]]) {
            [fileBrowserCell removeGestureRecognizer:gesture];
            break;
        }
    }

    // Long tap recognizer
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressAction:)];
    [fileBrowserCell addGestureRecognizer:longPressRecognizer];

    // Add the OK/Cancel buttons when renaming
    // Release previous accessoryView
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
        FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);
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
            FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);
            // Delete file from server
            NSMutableArray *filesArray = [NSMutableArray arrayWithObject:fileItem];

            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                      animated:YES];
            if (ServerSupportsFeature(DeleteCancel))
            {
                hud.allowsCancelation = YES;
            }
            hud.delegate = self;
            hud.labelText = NSLocalizedString(@"Deleting", nil);
            hud.tag = TAG_HUD_DELETE;
            
            [self.connectionManager deleteFiles:filesArray];
            
            [self.filesArray removeObjectAtIndex:indexPath.row];
            [self.multipleSelectionTableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView.isEditing)
    {
        [self.selectedIndexes addIndex:indexPath.row];
        self.deleteFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Delete (%d)",nil),[self.selectedIndexes count]];
        [self.deleteFilesButtonItem setEnabled:YES];
        self.moveCopyFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Copy/Move (%d)",nil),[self.selectedIndexes count]];
        [self.moveCopyFilesButtonItem setEnabled:YES];
        self.compressFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Compress (%d)",nil),[self.selectedIndexes count]];
        [self.compressFilesButtonItem setEnabled:YES];
    }
    else
    {
        FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);
        switch ([fileItem fileType])
        {
            case FILETYPE_FOLDER:
            {
                FileBrowserViewController *fileBrowserViewController = [[FileBrowserViewController alloc] init];
                fileBrowserViewController.serverPath = fileItem.path;
                fileBrowserViewController.userAccount = self.userAccount; // Not needed, may be useful for future needs
                fileBrowserViewController.connectionManager = self.connectionManager;
                [self.navigationController pushViewController:fileBrowserViewController animated:YES];
                break;
            }
            case FILETYPE_ARCHIVE:
            {
                // on iPad, presenting FormSheet will not make current view disappear, unregister notifications manually
                if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad))
                {
                    [self.connectionManager removeObserver:self];
                }
                
                // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
                // even with UIModalPresentationFormSheet (not the default behavior)
                ExtractViewController *extractViewController = [[ExtractViewController alloc] init];
                extractViewController.connectionManager = self.connectionManager;
                extractViewController.file = fileItem;
                extractViewController.destDir = self.serverPath;
                extractViewController.delegate = self;
                CustomNavigationController *extractNavController = [[CustomNavigationController alloc] initWithRootViewController:extractViewController];
                extractNavController.modalPresentationStyle = UIModalPresentationFormSheet;
                [self.navigationController presentModalViewController:extractNavController animated:YES];
                break;
            }
            case FILETYPE_QT_VIDEO:
            case FILETYPE_QT_AUDIO:
            {
                NetworkConnection *networkConnection = [self.connectionManager urlForFile:fileItem];
                if (ServerSupportsFeature(QTPlayer))
                {
                    // Internal player can handle this media
                    CustomMoviePlayerViewController *mp = [[CustomMoviePlayerViewController alloc] initWithContentURL:networkConnection.url];
                    mp.allowsAirPlay = ServerSupportsFeature(AirPlay);
                    if (mp) {
                        [self presentMoviePlayerViewControllerAnimated:mp];
                        [mp startPlaying];
                    }
                }
                else
                {
                    // Fallback to VLC media player
                    MVLCMovieViewController *movieViewController = [[MVLCMovieViewController alloc] init];
                    movieViewController.networkConnection = [self.connectionManager urlForVideo:fileItem];
                    // Hide tabbar & navbar and push view
                    [(CustomTabBarController *)self.tabBarController setTabBarHidden:YES withAnimation:YES];
                    [self.navigationController setNavigationBarHidden:YES animated:YES];
                    
                    [self.navigationController pushViewController:movieViewController animated:YES];
                }
                break;
            }
            case FILETYPE_VLC_VIDEO:
            case FILETYPE_VLC_AUDIO:
            {
                MVLCMovieViewController *movieViewController = [[MVLCMovieViewController alloc] init];
                movieViewController.networkConnection = [self.connectionManager urlForVideo:fileItem];
                // Hide tab bar controller
                [(CustomTabBarController *)self.tabBarController setTabBarHidden:YES withAnimation:YES];

                // Hide tabbar & navbar and push view
                [(CustomTabBarController *)self.tabBarController setTabBarHidden:YES withAnimation:YES];
                [self.navigationController setNavigationBarHidden:YES animated:YES];
                
                [self.navigationController pushViewController:movieViewController animated:YES];
                break;
            }
            case FILETYPE_PDF:
            {
                NSString *phrase = nil; // Document password (for unlocking most encrypted PDF files)
                
                NetworkConnection *networkConnection = [self.connectionManager urlForFile:fileItem];

                // Only possible if file is available locally
                if (networkConnection.urlType == URLTYPE_LOCAL)
                {
                    ReaderDocument *document = [[ReaderDocument alloc] initWithFilePath:[networkConnection.url relativePath] password:phrase];
                    
                    if (document != nil) // Must have a valid ReaderDocument object in order to proceed
                    {
                        ReaderViewController *readerViewController = [[ReaderViewController alloc] initWithReaderDocument:document];
                        
                        readerViewController.delegate = self; // Set the ReaderViewController delegate to self
                        
                        readerViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
                        readerViewController.modalPresentationStyle = UIModalPresentationFullScreen;
                        
                        [self presentModalViewController:readerViewController animated:YES];
                        
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
                    RBFilePreviewer *preview = [[RBFilePreviewer alloc] initWithFile:networkConnection.url];
                    preview.navBarTintColor = [UIColor blackColor];
                    preview.toolBarTintColor = [UIColor blackColor];
                    [self.navigationController pushViewController:preview animated:YES];
                }
                break;
            }
            case FILETYPE_PHOTO:
            {
                // View all photos in folder
                self.photos = [NSMutableArray array];
                
                NSInteger photoIndex = 0;
                NSInteger index = 0;
                for (FileItem *file in self.filesArray)
                {
                    if (file == fileItem)
                    {
                        photoIndex = index;
                    }
                    if ([file fileType] == FILETYPE_PHOTO)
                    {
                        MWPhoto *photo = [MWPhoto photoWithURL:[self.connectionManager urlForFile:file].url];
                        photo.caption = file.name;
                        [self.photos addObject:photo];
                        index++;
                    }
                }
                
                // Create & present browser
                MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
                // Set options
                browser.wantsFullScreenLayout = YES; // Decide if you want the photo browser full screen, i.e. whether the status bar is affected (defaults to YES)
                browser.displayActionButton = YES; // Show action button to save, copy or email photos (defaults to NO)
                [browser setInitialPageIndex:photoIndex];
                
                // Present navigation controller
                UINavigationController *navControler = [[UINavigationController alloc] initWithRootViewController:browser];
                [self presentModalViewController:navControler animated:YES];
                break;
            }
            default:
            {
                // For not handled types, show action menu
                [self showActionMenuForItemAtIndexPath:indexPath];

                break;
            }
        }
        // deselect the cell
        [self.multipleSelectionTableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.isEditing) {
        [self.selectedIndexes removeIndex:indexPath.row];
        if ([self.selectedIndexes count] == 0) {
            self.deleteFilesButtonItem.title = NSLocalizedString(@"Delete",nil);
            [self.deleteFilesButtonItem setEnabled:NO];
            self.moveCopyFilesButtonItem.title = NSLocalizedString(@"Copy/Move",nil);
            [self.moveCopyFilesButtonItem setEnabled:NO];
            self.compressFilesButtonItem.title = NSLocalizedString(@"Compress",nil);
            [self.compressFilesButtonItem setEnabled:NO];
        } else {
            self.deleteFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Delete (%d)",nil),[self.selectedIndexes count]];
            [self.deleteFilesButtonItem setEnabled:YES];
            self.moveCopyFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Copy/Move (%d)",nil),[self.selectedIndexes count]];
            [self.moveCopyFilesButtonItem setEnabled:YES];
            self.compressFilesButtonItem.title = [NSString stringWithFormat:NSLocalizedString(@"Compress (%d)",nil),[self.selectedIndexes count]];
            [self.compressFilesButtonItem setEnabled:YES];
        }
    }
}

#pragma mark - ReaderViewControllerDelegate methods

- (void)dismissReaderViewController:(ReaderViewController *)viewController
{
	[self dismissModalViewControllerAnimated:YES];
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
        NSIndexPath *pressedIndexPath = [self.multipleSelectionTableView indexPathForRowAtPoint:
                                         [longPressRecognizer locationInView:self.multipleSelectionTableView]];
        
        if (pressedIndexPath && (pressedIndexPath.row != NSNotFound) && (pressedIndexPath.section != NSNotFound))
        {
            [self showActionMenuForItemAtIndexPath:pressedIndexPath];
        }
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == -1)
    {
		// Do nothing
		return;
	}
    
    if (actionSheet == self.actionSheet)
    {
        if (buttonIndex == self.createFolderActionButtonIndex)
        {
            UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Create folder",nil)
                                                                  message:@"\n\n"
                                                                 delegate:self
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel",nil)
                                                        otherButtonTitles:NSLocalizedString(@"OK",nil), nil];
            [myAlertView setTag:TAG_ALERT_CREATE_FOLDER];
            
            self.folderNameField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 45.0, 260.0, 25.0)];
            [self.folderNameField setBackgroundColor:[UIColor whiteColor]];
            self.folderNameField.font = [UIFont systemFontOfSize:15];
            self.folderNameField.textAlignment = UITextAlignmentCenter;
            self.folderNameField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
            self.folderNameField.keyboardType = UIKeyboardTypeDefault;
            self.folderNameField.autocorrectionType = UITextAutocorrectionTypeNo;
            self.folderNameField.delegate = self;
            self.folderNameField.tag = TAG_TEXTFIELD_CREATE_FOLDER;
            
            [myAlertView addSubview:self.folderNameField];
            [myAlertView show];

        }
        else if (buttonIndex == self.reloadActionButtonIndex)
        {
            [self.connectionManager listForPath:self.serverPath];
        }
        else if (buttonIndex == self.sortItemsActionButtonIndex)
        {
            // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
            // even with UIModalPresentationFormSheet (not the default behavior)
            SortItemsViewController *sortItemsViewController = [[SortItemsViewController alloc] initWithSortingType:self.sortingType];
            sortItemsViewController.delegate = self;
            CustomNavigationController *moveNavController = [[CustomNavigationController alloc] initWithRootViewController:sortItemsViewController];
            moveNavController.modalPresentationStyle = UIModalPresentationFormSheet;
            [self.navigationController presentModalViewController:moveNavController animated:YES];
        }
    }
    else if (actionSheet == self.itemActionSheet)
    {
        FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:actionSheet.tag]);
        if (actionSheet.destructiveButtonIndex == buttonIndex)
        {
            // Ask for deletion confirmation
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Delete file",@"")
															message:fileItem.name
														   delegate:self
												  cancelButtonTitle:NSLocalizedString(@"Cancel",@"")
												  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
			alert.tag = TAG_ALERT_DELETE_BASE + actionSheet.tag;
			[alert show];
        }
        else if (buttonIndex == self.renameButtonIndex)
        {
			FileBrowserCell *cell = (FileBrowserCell *)[self.multipleSelectionTableView cellForRowAtIndexPath:
                                                        [NSIndexPath indexPathForRow:actionSheet.tag inSection:0]];
            
            // Save the cell for handling everything right after ...
            self.editedCell = cell;
            
            // Disable selection of cells
            self.multipleSelectionTableView.allowsSelection = NO;
            
			/* Remove long tap handling (need to be restored at the end of renaming) */
            NSInteger rows = [self.multipleSelectionTableView numberOfRowsInSection:0];
            NSInteger index;
            for (index = 0; index < rows; index++)
            {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                UITableViewCell *oneCell = [self.multipleSelectionTableView cellForRowAtIndexPath:indexPath];
                
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
            NSArray *fileItems = [NSArray arrayWithObject:fileItem];

            // on iPad, presenting FormSheet will not make current view disappear, unregister notifications manually
            if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad))
            {
                [self.connectionManager removeObserver:self];
            }
            
            // Push all needed views
            NSArray *pathArray = [self.serverPath componentsSeparatedByString:@"/"];
            NSString *path = @"/";
            
            CustomNavigationController *moveNavController = [[CustomNavigationController alloc] init];
            moveNavController.modalPresentationStyle = UIModalPresentationFormSheet;
            for (NSString *pathComponent in pathArray)
            {
                path = [path stringByAppendingPathComponent:pathComponent];
                // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
                // even with UIModalPresentationFormSheet (not the default behavior)
                MoveFileViewController *moveFileViewController = [[MoveFileViewController alloc] initWithPath:path
                                                                                                   sourcePath:self.serverPath
                                                                                                     andFiles:fileItems];
                moveFileViewController.title = path;
                moveFileViewController.delegate = self;
                moveFileViewController.connectionManager = self.connectionManager;
                [moveNavController pushViewController:moveFileViewController animated:NO];
            }
            [self.navigationController presentModalViewController:moveNavController animated:YES];
        }
        else if (buttonIndex == self.compressButtonIndex)
        {
            NSMutableArray *fileItems = [NSMutableArray arrayWithObject:fileItem];
            
            // on iPad, presenting FormSheet will not make current view disappear, unregister notifications manually
            if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad))
            {
                [self.connectionManager removeObserver:self];
            }
            
            NSString *archiveName = [((FileItem *)[fileItems objectAtIndex:0]).name stringByAppendingString:@".zip"];

            // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
            // even with UIModalPresentationFormSheet (not the default behavior)
            CompressViewController *compressViewController = [[CompressViewController alloc] init];
            compressViewController.connectionManager = self.connectionManager;
            compressViewController.files = fileItems;
            compressViewController.atPath = self.serverPath;
            compressViewController.destDir = self.serverPath;
            compressViewController.destArchive = archiveName;
            compressViewController.delegate = self;
            CustomNavigationController *compressNavController = [[CustomNavigationController alloc] initWithRootViewController:compressViewController];
            compressNavController.modalPresentationStyle = UIModalPresentationFormSheet;
            [self.navigationController presentModalViewController:compressNavController animated:YES];
        }
        else if (buttonIndex == self.extractButtonIndex)
        {
            // on iPad, presenting FormSheet will not make current view disappear, unregister notifications manually
            if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad))
            {
                [self.connectionManager removeObserver:self];
            }
            
            // The purpose of the CustomNavigationController is to make keyboard diseappear automatically
            // even with UIModalPresentationFormSheet (not the default behavior)
            ExtractViewController *extractViewController = [[ExtractViewController alloc] init];
            extractViewController.connectionManager = self.connectionManager;
            extractViewController.file = fileItem;
            extractViewController.destDir = self.serverPath;
            extractViewController.delegate = self;
            CustomNavigationController *extractNavController = [[CustomNavigationController alloc] initWithRootViewController:extractViewController];
            extractNavController.modalPresentationStyle = UIModalPresentationFormSheet;
            [self.navigationController presentModalViewController:extractNavController animated:YES];
        }
        else if (buttonIndex == self.openInButtonIndex)
        {
            NSURL *fileURL = [self.connectionManager urlForFile:fileItem].url;
            self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
            
            self.documentInteractionController.delegate = self;
            
            // Present an Open in menu
            CGRect openInRect;
            UIView *openInView = nil;
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            {
                openInRect = CGRectZero;
                openInView = self.view.superview;
                
                // Parse visible cells to find the good one
                for (FileBrowserCell *cell in self.multipleSelectionTableView.visibleCells)
                {
                    if ([cell.nameLabel.text isEqualToString:fileItem.name])
                    {
                        openInRect = cell.frame;
                        openInView = self.view;
                        break;
                    }
                }
            }
            else
            {
                openInRect = CGRectZero;
                openInView = self.view.superview;
            }
            
            [self.documentInteractionController presentOptionsMenuFromRect:openInRect
                                                                    inView:openInView
                                                                  animated:YES];
        }
        else if (buttonIndex == self.downloadButtonIndex)
        {
            // TODO : create a download/upload queue manager which will handle all requested downloads
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                      animated:YES];
            if (ServerSupportsFeature(DownloadCancel))
            {
                hud.allowsCancelation = YES;
            }
            hud.delegate = self;
            hud.labelText = NSLocalizedString(@"Downloading", nil);
            hud.tag = TAG_HUD_DOWNLOAD;
            
            [self.connectionManager downloadFile:fileItem toLocalName:fileItem.name];
        }
        else
        {
            // TODO : create a download/upload queue manager which will handle all requested downloads
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                      animated:YES];
            if (ServerSupportsFeature(UploadCancel))
            {
                hud.allowsCancelation = YES;
            }
            hud.delegate = self;
            hud.labelText = NSLocalizedString(@"Uploading", nil);
            hud.tag = TAG_HUD_UPLOAD;

            [self.connectionManager uploadLocalFile:@"test.zip" toPath:self.serverPath overwrite:YES];
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
            [hud hide:YES];
            break;
        }
        case TAG_HUD_COPY:
        {
            [self.connectionManager cancelCopyTask];
            [hud hide:YES];
            break;
        }
        case TAG_HUD_MOVE:
        {
            [self.connectionManager cancelMoveTask];
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

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return self.photos.count;
}

- (MWPhoto *)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index < self.photos.count)
        return [self.photos objectAtIndex:index];
    return nil;
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
            

            // If the name changed, proceed with rename
            if (![textField.text isEqualToString:self.editedCell.oldName])
            {
                [self.connectionManager renameFile:self.editedCell.oldName
                                            toName:textField.text atPath:self.serverPath];
                
                // Parse the filesArray to rename the element here
                for (FileItem *file in self.filesArray)
                {
                    if ([file.name isEqualToString:self.editedCell.oldName]) {
                        NSRange filenameRange = NSMakeRange([file.path length]-[file.name length], [file.name length]);
                        file.path =  [file.path stringByReplacingCharactersInRange:filenameRange
                                                           withString:textField.text];
                        filenameRange = NSMakeRange([file.fullPath length]-[file.name length], [file.name length]);
                        file.fullPath = [file.fullPath stringByReplacingCharactersInRange:filenameRange
                                                           withString:textField.text];

                        file.name = textField.text;
                    }
                }
                
                self.editedCell.oldName = textField.text;
            }
            
			[self.editedCell setUneditable];
			
            // Restore selection of files
            self.multipleSelectionTableView.allowsSelection = YES;
            
			/* Restore long tap handling (was removed at start of renaming) */
            NSInteger rows = [self.multipleSelectionTableView numberOfRowsInSection:0];
            NSInteger index;
            for (index = 0; index < rows; index++)
            {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                UITableViewCell *oneCell = [self.multipleSelectionTableView cellForRowAtIndexPath:indexPath];
                
				// Long tap recognizer
                UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                                  action:@selector(longPressAction:)];
                [oneCell addGestureRecognizer:longPressRecognizer];

				// Enable touch detection for cells
				oneCell.userInteractionEnabled = YES;
            }
			break;
		}
		default:
			break;
	}
}

#pragma mark - UIAlertViewDelegate functions

- (void)didPresentAlertView:(UIAlertView *)alertView
{
	if (([alertView tag] == TAG_ALERT_CREATE_FOLDER))
    {
		[self.folderNameField becomeFirstResponder];
	}
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == -1)
		return;
    
    if (self.multipleSelectionTableView.isEditing)
    {
        if (alertView.firstOtherButtonIndex == buttonIndex) {
            // Delete files if ok
            
            NSMutableArray *filesArray = [NSMutableArray array];
            
            NSUInteger current_index = [self.selectedIndexes firstIndex];
            NSMutableArray *indexPathsForSelectedIndexes = [NSMutableArray array];
            while (current_index != NSNotFound)
            {
                FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:current_index]);
                [filesArray addObject:fileItem];
                
                [indexPathsForSelectedIndexes addObject:[NSIndexPath indexPathForRow:current_index inSection:0]];
                
                current_index = [self.selectedIndexes indexGreaterThanIndex: current_index];
            }
            
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                      animated:YES];
            if (ServerSupportsFeature(DeleteCancel))
            {
                hud.allowsCancelation = YES;
            }
            hud.delegate = self;
            hud.labelText = NSLocalizedString(@"Deleting", nil);
            hud.tag = TAG_HUD_DELETE;

            [self.connectionManager deleteFiles:filesArray];
            
            NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
            for (NSIndexPath *indexPath in indexPathsForSelectedIndexes)
            {
                [indexSet addIndex:indexPath.row];
            }
            [self.filesArray removeObjectsAtIndexes:indexSet];
            
            [self.multipleSelectionTableView deleteRowsAtIndexPaths:indexPathsForSelectedIndexes
                                                   withRowAnimation:UITableViewRowAnimationFade];
            
            [self toggleEditButton];
        }
    }
    else
    {
        switch (alertView.tag)
        {
            case TAG_ALERT_CREATE_FOLDER:
            {
                if ((buttonIndex == alertView.firstOtherButtonIndex) && ([self.folderNameField text] != nil) && (![[self.folderNameField text] isEqualToString:@""]))
                {
                    [self createFolder:[self.folderNameField text]
                                atPath:self.serverPath];
                }
                break;
            }
            case TAG_ALERT_DO_NOTHING:
            {
                // Do nothing
                break;
            }
            default:
            {
                if ((alertView.tag & TAG_ALERT_DELETE_BASE) == TAG_ALERT_DELETE_BASE)
                {
                    if (alertView.firstOtherButtonIndex == buttonIndex)
                    {
                        NSInteger index = alertView.tag & ~TAG_ALERT_DELETE_BASE;
                        FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:index]);
                        
                        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                                                  animated:YES];
                        if (ServerSupportsFeature(DeleteCancel))
                        {
                            hud.allowsCancelation = YES;
                        }
                        hud.delegate = self;
                        hud.labelText = NSLocalizedString(@"Deleting", nil);
                        hud.tag = TAG_HUD_DELETE;

                        // Delete file from server
                        NSMutableArray *filesArray = [NSMutableArray arrayWithObject:fileItem];
                        [self.connectionManager deleteFiles:filesArray];
                        
                        // Delete file from tableView
                        [self.filesArray removeObjectAtIndex:index];
                        [self.multipleSelectionTableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:
                                                                                 [NSIndexPath indexPathForRow:index inSection:0]]
                                                               withRowAnimation:UITableViewRowAnimationFade];
                        [self.multipleSelectionTableView reloadData];
                    }
                }
            }
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
    }
    hud.delegate = self;
    hud.labelText = NSLocalizedString(@"Compress", nil);
    hud.tag = TAG_HUD_COMPRESS;
    
    [self.connectionManager compressFiles:files
                                toArchive:archive
                              archiveType:archiveType
                         compressionLevel:compressionLevel
                                 password:password
                                overwrite:overwrite];
}

#pragma mark - ExtractViewController delegate

- (void)extractFile:(FileItem *)fileItem
           toSubdir:(NSString *)toSubdir
       withPassword:(NSString *)password
          overwrite:(BOOL)overwrite
  extractWithFolder:(BOOL)extractFolders
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                              animated:YES];
    if (ServerSupportsFeature(ExtractCancel))
    {
        hud.allowsCancelation = YES;
    }
    hud.delegate = self;
    hud.labelText = NSLocalizedString(@"Extract", nil);
    hud.tag = TAG_HUD_EXTRACT;
    
    [self.connectionManager extractFile:fileItem
                               toSubdir:toSubdir
                           withPassword:password
                              overwrite:overwrite
                      extractWithFolder:extractFolders];
}

#pragma mark - MoveFileViewController delegate

- (void)moveFiles:(NSArray *)files toPath:(NSString *)toPath andOverwrite:(BOOL)overwrite
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                              animated:YES];
    if (ServerSupportsFeature(MoveCancel))
    {
        hud.allowsCancelation = YES;
    }
    hud.delegate = self;
    hud.labelText = NSLocalizedString(@"Move", nil);
    hud.tag = TAG_HUD_MOVE;
 
    [self.connectionManager moveFiles:files
                               toPath:toPath
                         andOverwrite:overwrite];
}

- (void)copyFiles:(NSArray *)files toPath:(NSString *)toPath andOverwrite:(BOOL)overwrite
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                              animated:YES];
    if (ServerSupportsFeature(CopyCancel))
    {
        hud.allowsCancelation = YES;
    }
    hud.delegate = self;
    hud.labelText = NSLocalizedString(@"Copy", nil);
    hud.tag = TAG_HUD_COPY;
    
	[self.connectionManager copyFiles:files
                               toPath:toPath
                         andOverwrite:overwrite];
}

- (void)createFolder:(NSString *)folder atPath:(NSString *)path
{
    [self.connectionManager createFolder:folder
                                  atPath:path];
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
#warning Why the hell do I have to remove 50 ???
        multipleSelectionTableContentInset = UIEdgeInsetsMake(0.0f, 0.0f, kbSize.height - 50.0, 0.0f);
    }
    else
    {
        multipleSelectionTableContentInset = UIEdgeInsetsMake(0.0f, 0.0f, kbSize.width - 50.0, 0.0f);
    }
    
    self.multipleSelectionTableView.contentInset = multipleSelectionTableContentInset;
    self.multipleSelectionTableView.scrollIndicatorInsets = multipleSelectionTableContentInset;
    
    [self.multipleSelectionTableView scrollRectToVisible:self.editedCell.frame animated:YES];
}

-(void) keyboardWillHide:(NSNotification *)notification
{
	UIEdgeInsets multipleSelectionTableContentInset = UIEdgeInsetsZero;
    self.multipleSelectionTableView.contentInset = multipleSelectionTableContentInset;
    self.multipleSelectionTableView.scrollIndicatorInsets = multipleSelectionTableContentInset;
}

#pragma mark - ConnectionManager protocol

- (void)CMLogin:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
    
    // If login is ok, request list
    if ([[[notification userInfo] objectForKey:@"success"] boolValue])
    {
        [self.connectionManager listForPath:self.serverPath];
        [self.connectionManager spaceInfoAtPath:self.serverPath];
    }
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Login",@"")
														message:NSLocalizedString([[notification userInfo] objectForKey:@"error"],@"")
													   delegate:nil
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
		[alert show];
        
        // Go back to servers list
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)CMFilesList:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
    
    [self.refreshControl endRefreshing];
    
    // Check if the notification is for this folder
    if ([self.serverPath isEqualToString:[[notification userInfo] objectForKey:@"path"]])
    {
        NSArray *filesList = [[notification userInfo] objectForKey:@"filesList"];
        
        self.filesArray = [[NSMutableArray alloc] init];
        
        int i;
        for (i=0; i<[filesList count];i++)
        {
            FileItem *fileItem = [[FileItem alloc] init];
            fileItem.name = [[filesList objectAtIndex:i] objectForKey:@"filename"];
            fileItem.isDir = [[[filesList objectAtIndex:i] objectForKey:@"isdir"] boolValue];
            fileItem.shortPath = self.serverPath;
            if ([self.serverPath isEqualToString:@"/"])
            {
                fileItem.path = [NSString stringWithFormat:@"/%@",fileItem.name]; // Path to file
            }
            else
            {
                fileItem.path = [NSString stringWithFormat:@"%@/%@",self.serverPath,fileItem.name]; // Path to file
            }
            if ([[filesList objectAtIndex:i] objectForKey:@"path"])
            {
                fileItem.fullPath = [[filesList objectAtIndex:i] objectForKey:@"path"]; // Path with filename/foldername
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
                fileItem.owner = nil;
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
            [self.filesArray addObject:fileItem];
        }
        
        // Sort files array
        [self.filesArray sortFileItemArrayWithOrder:self.sortingType];
        
        // Refresh tableView
        [self.multipleSelectionTableView performSelectorOnMainThread:@selector(reloadData)
                                                          withObject:nil
                                                       waitUntilDone:NO];
    }
}

- (void)CMSpaceInfo:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
    
    // TODO : Find a smart way to present this information ...
    if ([[[notification userInfo] objectForKey:@"success"] boolValue])
    {
//        uint64_t totalSpace = [[[notification userInfo] objectForKey:@"totalspace"] floatValue];
//        uint64_t freeSpace = [[[notification userInfo] objectForKey:@"freespace"] floatValue];
        NSLog(@"Total Space : %@", [[[notification userInfo] objectForKey:@"totalspace"] stringForNumberOfBytes]);
        NSLog(@"Free Space : %@", [[[notification userInfo] objectForKey:@"freespace"] stringForNumberOfBytes]);
    }
}

- (void)CMRename:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
	
	if ([[[notification userInfo] objectForKey:@"success"] boolValue] == NO)
    {
		// TODO : if it fails, restore the old name and paths instead of refreshing list
        
        // Update file list
        [self.connectionManager listForPath:self.serverPath];
        
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File rename",@"")
														message:NSLocalizedString([[notification userInfo] objectForKey:@"error"],@"")
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    else
    {
		// Refresh file list to refresh file type if needed
		[self.connectionManager listForPath:self.serverPath];
    }
}

- (void)CMDeleteProgress:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
	
    float progress = [[[notification userInfo] objectForKey:@"progress"] floatValue];
    if (progress != 0)
    {
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = progress;
    }
}

- (void)CMDeleteFinished:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
	
	if ([[[notification userInfo] objectForKey:@"success"] boolValue] == NO)
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File delete",@"")
														message:NSLocalizedString([[notification userInfo] objectForKey:@"error"],@"")
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
		
		// Get file list
		[self.connectionManager listForPath:self.serverPath];
	}
    else
    {
        // Get new space info
        [self.connectionManager spaceInfoAtPath:self.serverPath];
    }
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMCreateFolder:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
	
	if ([[[notification userInfo] objectForKey:@"success"] boolValue])
    {
		// Get file list
		[self.connectionManager listForPath:self.serverPath];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Create folder",@"")
														message:NSLocalizedString([[notification userInfo] objectForKey:@"error"],@"")
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
}

- (void)CMCopyProgress:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
	
    float progress = [[[notification userInfo] objectForKey:@"progress"] floatValue];
    if (progress != 0)
    {
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = progress;
    }
}

- (void)CMCopyFinished:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
	
    // TODO : Find a smart way to present this information ...
	if ([[[notification userInfo] objectForKey:@"success"] boolValue])
    {
        // Update space information
        [self.connectionManager spaceInfoAtPath:self.serverPath];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File copy",@"")
														message:NSLocalizedString([[notification userInfo] objectForKey:@"error"],@"")
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMMoveProgress:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
	
    float progress = [[[notification userInfo] objectForKey:@"progress"] floatValue];
    if (progress != 0)
    {
        MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = progress;
    }
}

- (void)CMMoveFinished:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
	
    // TODO : Find a smart way to present this information ...
	if ([[[notification userInfo] objectForKey:@"success"] boolValue])
    {
		// Get file list
		[self.connectionManager listForPath:self.serverPath];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File move",@"")
														message:NSLocalizedString([[notification userInfo] objectForKey:@"error"],@"")
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMDownloadProgress:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
	
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    if ([[notification userInfo] objectForKey:@"progress"])
    {
        float progress = [[[notification userInfo] objectForKey:@"progress"] floatValue];
        if (progress != 0)
        {
            hud.mode = MBProgressHUDModeAnnularDeterminate;
            hud.progress = progress;
        }
        if ([[notification userInfo] objectForKey:@"downloadedBytes"])
        {
            NSNumber *downloaded = [[notification userInfo] objectForKey:@"downloadedBytes"];
            NSNumber *totalSize = [[notification userInfo] objectForKey:@"totalBytes"];
            hud.detailsLabelText = [NSString stringWithFormat:@"%@ of %@ done",[downloaded stringForNumberOfBytes],[totalSize stringForNumberOfBytes]];
        }
    }
    else
    {
        NSNumber *downloaded = [[notification userInfo] objectForKey:@"downloadedBytes"];
        hud.detailsLabelText = [NSString stringWithFormat:@"%@ done",[downloaded stringForNumberOfBytes]];
    }
}

- (void)CMDownloadFinished:(NSNotification *)notification
{
	if ([notification userInfo] == nil) return;
	
    // TODO : Find a smart way to present this information ...
	if ([[[notification userInfo] objectForKey:@"success"] boolValue])
    {
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File download",@"")
														message:NSLocalizedString([[notification userInfo] objectForKey:@"error"],@"")
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}


- (void)CMUploadProgress:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
	
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    if ([[notification userInfo] objectForKey:@"progress"])
    {
        float progress = [[[notification userInfo] objectForKey:@"progress"] floatValue];
        if (progress != 0)
        {
            hud.mode = MBProgressHUDModeAnnularDeterminate;
            hud.progress = progress;
        }
        if ([[notification userInfo] objectForKey:@"uploadedBytes"])
        {
            NSNumber *uploaded = [[notification userInfo] objectForKey:@"uploadedBytes"];
            NSNumber *totalSize = [[notification userInfo] objectForKey:@"totalBytes"];
            hud.detailsLabelText = [NSString stringWithFormat:@"%@ of %@ done",[uploaded stringForNumberOfBytes],[totalSize stringForNumberOfBytes]];
        }
    }
    else
    {
        NSNumber *uploaded = [[notification userInfo] objectForKey:@"uploadedBytes"];
        hud.detailsLabelText = [NSString stringWithFormat:@"%@ done",[uploaded stringForNumberOfBytes]];
    }
}

- (void)CMUploadFinished:(NSNotification *)notification
{
	if ([notification userInfo] == nil) return;
	
	if ([[[notification userInfo] objectForKey:@"success"] boolValue])
    {
		// Get file list
		[self.connectionManager listForPath:self.serverPath];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"File upload",@"")
														message:NSLocalizedString([[notification userInfo] objectForKey:@"error"],@"")
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMCompressProgress:(NSNotification *)notification
{
	if ([notification userInfo] == nil) return;
	
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    float progress = [[[notification userInfo] objectForKey:@"progress"] floatValue];
    if (progress != 0)
    {
        hud.mode = MBProgressHUDModeAnnularDeterminate;
        hud.progress = progress;
    }

    NSNumber *done = [[notification userInfo] objectForKey:@"compressedBytes"];
    NSNumber *totalSize = [[notification userInfo] objectForKey:@"totalBytes"];
    if (([[notification userInfo] objectForKey:@"currentFile"]) && done && totalSize)
    {
        hud.labelText = [NSString stringWithFormat:NSLocalizedString(@"Compress %@",nil),[[notification userInfo] objectForKey:@"currentFile"]];
    }
    else if ([[notification userInfo] objectForKey:@"currentFile"])
    {
        hud.detailsLabelText = [[notification userInfo] objectForKey:@"currentFile"];
    }

    if (done && totalSize)
    {
        hud.detailsLabelText = [NSString stringWithFormat:@"%@ of %@ done",[done stringForNumberOfBytes],[totalSize stringForNumberOfBytes]];
    }
}

- (void)CMCompressFinished:(NSNotification *)notification
{
	if ([notification userInfo] == nil) return;
	
    // TODO : Find a smart way to present this information ...
	if ([[[notification userInfo] objectForKey:@"success"] boolValue])
    {
        // Update list
		[self.connectionManager listForPath:self.serverPath];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Compress",@"")
														message:NSLocalizedString([[notification userInfo] objectForKey:@"error"],@"")
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMExtractProgress:(NSNotification *)notification
{
	if ([notification userInfo] == nil) return;
	
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    hud.mode = MBProgressHUDModeAnnularDeterminate;
    hud.progress = [[[notification userInfo] objectForKey:@"progress"] floatValue];
    NSNumber *done = [[notification userInfo] objectForKey:@"extractedBytes"];
    NSNumber *totalSize = [[notification userInfo] objectForKey:@"totalBytes"];
    if (([[notification userInfo] objectForKey:@"currentFile"]) && done && totalSize)
    {
        hud.labelText = [NSString stringWithFormat:NSLocalizedString(@"Extract %@",nil),[[notification userInfo] objectForKey:@"currentFile"]];
    }
    else if ([[notification userInfo] objectForKey:@"currentFile"])
    {
        hud.detailsLabelText = [[notification userInfo] objectForKey:@"currentFile"];
    }
    
    if (done && totalSize)
    {
        hud.detailsLabelText = [NSString stringWithFormat:@"%@ of %@ done",[done stringForNumberOfBytes],[totalSize stringForNumberOfBytes]];
    }
}

- (void)CMExtractFinished:(NSNotification *)notification
{
	if ([notification userInfo] == nil) return;
	
	if ([[[notification userInfo] objectForKey:@"success"] boolValue])
    {
        // Update list
		[self.connectionManager listForPath:self.serverPath];
	}
    else
    {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Extract",@"")
														message:NSLocalizedString([[notification userInfo] objectForKey:@"error"],@"")
													   delegate:self
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
        alert.tag = TAG_ALERT_DO_NOTHING;
		[alert show];
	}
    
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];
}

- (void)CMConnectionError:(NSNotification*)notification
{
	if ([notification userInfo] == nil) return;
	
    // We should hide HUD if any ...
    MBProgressHUD *hud = [MBProgressHUD HUDForView:self.view];
    [hud hide:YES];

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Connection error",@"")
													message:NSLocalizedString([[notification userInfo] objectForKey:@"error"],@"")
												   delegate:self
										  cancelButtonTitle:nil
										  otherButtonTitles:NSLocalizedString(@"OK",@""),nil];
    alert.tag = TAG_ALERT_DO_NOTHING;
	[alert show];
}

#pragma mark - Orientation management

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation
{
    return YES;
}

#pragma mark - Item action sheet

- (void)showActionMenuForItemAtIndexPath:(NSIndexPath *)indexpath
{
    FileBrowserCell *aCell = (FileBrowserCell *)[self.multipleSelectionTableView cellForRowAtIndexPath:indexpath];
    FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:indexpath.row]);
    self.itemActionSheet = [[UIActionSheet alloc] initWithTitle:fileItem.name
                                                          delegate:self
                                                 cancelButtonTitle:nil
                                            destructiveButtonTitle:nil
                                                 otherButtonTitles:nil];
    self.itemActionSheet.actionSheetStyle = UIActionSheetStyleDefault;
    
    if ((fileItem.writeAccess) &&
        (
         (!fileItem.isDir && (ServerSupportsFeature(FileDelete))) ||
         (fileItem.isDir && (ServerSupportsFeature(FolderDelete)))
         )
        )
    {
        self.itemActionSheet.destructiveButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Delete",@"")];
    }
    else
    {
        self.itemActionSheet.destructiveButtonIndex = -1;
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
    
    if ((ServerSupportsFeature(OpenIn)) && (!fileItem.isDir))
    {
        self.openInButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Open in...",nil)];
    }
    else
    {
        self.openInButtonIndex = -1;
    }
    
    if ((ServerSupportsFeature(FileDownload)) && (!fileItem.isDir))
    {
        self.downloadButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Download locally",nil)];
    }
    else
    {
        self.downloadButtonIndex = -1;
    }

    if ((ServerSupportsFeature(FileDownload)) && (!fileItem.isDir))
    {
        [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"upload",nil)];
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
            self.itemActionSheet.cancelButtonIndex = [self.itemActionSheet addButtonWithTitle:NSLocalizedString(@"Cancel",@"")];
            [self.itemActionSheet showInView:self.parentViewController.tabBarController.view];
        }
    }
}

#pragma mark - Sorting option management

- (void)selectedSortingType:(FileItemSortType)sortingType
{
    self.sortingType = sortingType;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:sortingType forKey:@"sortingType"];
    [defaults synchronize];
    
    [self.filesArray sortFileItemArrayWithOrder:self.sortingType];
    [self.multipleSelectionTableView reloadData];
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
