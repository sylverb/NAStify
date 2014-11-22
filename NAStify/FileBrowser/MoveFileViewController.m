//
//  MoveFileViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "MoveFileViewController.h"
#import "FileBrowserCell.h"

@implementation MoveFileViewController

#pragma mark - Initialization

- (id)init
{
	if (self = [super init])
    {
		self.folderArray = nil;
	}
	return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.edgesForExtendedLayout = UIRectEdgeNone;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.rowHeight = 50.0;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight |
                                      UIViewAutoresizingFlexibleBottomMargin;
    
    [self.view addSubview:self.tableView];

	NSString *title = [[self.currentFolder.path componentsSeparatedByString:@"/"] lastObject];
    
	UIBarButtonItem *flexibleSpaceButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                             target:nil
                                                                                             action:nil];

    self.mvButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Move here",@"")
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(moveButton:event:)];
    self.cpButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Copy here",@"")
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(copyButton:event:)];
	UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                      target:self
                                                                                      action:@selector(cancelButton:event:)];
	UIBarButtonItem *addFolderButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                         target:self
                                                                                         action:@selector(addFolderButton:event:)];
	addFolderButtonItem.style = UIBarButtonItemStylePlain;
	
	if ([title length] == 0)
    {
		title = @"/";
    }
    
    NSMutableArray *buttons = [NSMutableArray array];
    
    if (ServerSupportsFeature(FileCopy) ||
        ServerSupportsFeature(FolderCopy))
    {
        [buttons addObjectsFromArray:[NSArray arrayWithObjects:
                                      flexibleSpaceButtonItem,
                                      self.cpButtonItem,
                                      nil]];
    }
    if (ServerSupportsFeature(FileMove) ||
        ServerSupportsFeature(FolderMove))
    {
        [buttons addObjectsFromArray:[NSArray arrayWithObjects:
                                      flexibleSpaceButtonItem,
                                      self.mvButtonItem,
                                      nil]];
    }
    if (ServerSupportsFeature(FolderCreate))
    {
        [buttons addObjectsFromArray:[NSArray arrayWithObjects:
                                      flexibleSpaceButtonItem,
                                      addFolderButtonItem,
                                      nil]];
    }
    [buttons addObjectsFromArray:[NSArray arrayWithObjects:
                                  flexibleSpaceButtonItem,
                                  cancelButtonItem,
                                  flexibleSpaceButtonItem,
                                  nil]];
	[self setToolbarItems:buttons];

	self.navigationItem.title = title;
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [self.navigationController.toolbar setTintColor:[UIColor blackColor]];
}

- (void)viewWillAppear:(BOOL)animated
{
	[self.navigationController setToolbarHidden:NO animated:NO];
    self.connectionManager.delegate = self;
	
    // We don't want to move files to their current location
    BOOL canCopyMoveHere = YES;
    for (FileItem *item in self.filesToMove)
    {
        if (item.isDir)
        {
            // Prevent recursive copy/move
            if (([self.currentFolder.path rangeOfString:item.path].location == 0) ||
                ([self.currentFolder.objectIds containsObject:[item.objectIds lastObject]]))
            {
                canCopyMoveHere = NO;
                break;
            }
        }
        if (([item.shortPath isEqual:self.currentFolder.path]) ||
            (([item.objectIds count] >= 2) &&
            ([[item.objectIds objectAtIndex:[item.objectIds count]-2] isEqual:[self.currentFolder.objectIds lastObject]])))
        {
            canCopyMoveHere = NO;
            break;
        }
    }
    if (canCopyMoveHere == NO)
    {
        [self.mvButtonItem setEnabled:NO];
        [self.cpButtonItem setEnabled:NO];
    }

    // Get file list if needed
	if ([self.folderArray count] == 0)
    {
		[self.connectionManager listForPath:self.currentFolder];
	}
    
    [super viewWillAppear:animated];
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
    return [self.folderArray count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *FileBrowserCellIdentifier = @"FileBrowserCell";
	FileItem *file = (FileItem *)([self.folderArray objectAtIndex:indexPath.row]);
	
    UITableViewCell *cell;
	FileBrowserCell *fileBrowserCell = (FileBrowserCell *)[tableView dequeueReusableCellWithIdentifier:FileBrowserCellIdentifier];
	if (fileBrowserCell == nil)
    {
		fileBrowserCell = [[FileBrowserCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                  reuseIdentifier:FileBrowserCellIdentifier];
	}
	
	// Configure the cell...
	[fileBrowserCell setFileItem:file
					withDelegate:self
						  andTag:TAG_TEXTFIELD_FILENAME];
	
	cell = fileBrowserCell;
	
	[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
	FileItem *fileItem = (FileItem *)([self.folderArray objectAtIndex:indexPath.row]);
	
	MoveFileViewController *moveFileViewController = [[MoveFileViewController alloc] init];
    moveFileViewController.delegate = self.delegate;
    moveFileViewController.connectionManager = self.connectionManager;
    moveFileViewController.currentFolder = fileItem;
    moveFileViewController.filesToMove = self.filesToMove;
	[self.navigationController pushViewController:moveFileViewController animated:YES];
}

#pragma mark - CMDelegate Callbacks

- (void)CMFilesList:(NSDictionary *)dict
{
	
	NSArray *filesList = [dict objectForKey:@"filesList"];
	
	int i;
	self.folderArray = [[NSMutableArray alloc] initWithCapacity:[filesList count]];
    
	for (i=0; i<[filesList count];i++)
    {
		if ([[[filesList objectAtIndex:i] objectForKey:@"isdir"] boolValue])
        {
			FileItem *fileItem = [[FileItem alloc] init];
			fileItem.name = [[filesList objectAtIndex:i] objectForKey:@"filename"];
			fileItem.isDir = YES;
			fileItem.shortPath = self.currentFolder.path;
            if ([self.currentFolder.path isEqualToString:@"/"])
            {
                fileItem.path = [NSString stringWithFormat:@"/%@",fileItem.name]; // Path to file
            }
            else
            {
                fileItem.path = [NSString stringWithFormat:@"%@/%@",self.currentFolder.path,fileItem.name]; // Path to file
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
            
            if ([[filesList objectAtIndex:i] objectForKey:@"id"])
            {
                fileItem.objectIds = [self.currentFolder.objectIds arrayByAddingObject:[[filesList objectAtIndex:i] objectForKey:@"id"]];
            }

			fileItem.type = [[filesList objectAtIndex:i] objectForKey:@"type"];
			fileItem.fileSize = @"";
			fileItem.fileSizeNumber = nil;
			fileItem.owner = nil;
			
			/* Date */
			fileItem.fileDateNumber = [NSNumber numberWithDouble:[[[filesList objectAtIndex:i] objectForKey:@"date"] doubleValue]];
			NSTimeInterval mtime = (NSTimeInterval)[[[filesList objectAtIndex:i] objectForKey:@"date"] doubleValue];
			NSDate *mdate = [NSDate dateWithTimeIntervalSince1970:mtime];
			NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
			[formatter setDateStyle:NSDateFormatterMediumStyle];
			[formatter setTimeStyle:NSDateFormatterShortStyle];
			
			fileItem.fileDate = [formatter stringFromDate:mdate];
			
			[self.folderArray addObject:fileItem];
		}
	}
    
    FileItemSortType sortingType;

    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    if ([defaults objectForKey:@"sortingType"])
    {
        sortingType = (FileItemSortType)[[defaults objectForKey:@"sortingType"] integerValue];
    }
    else
    {
        sortingType = SORT_BY_NAME_DESC_FOLDER_FIRST;
    }

	[self.folderArray sortFileItemArrayWithOrder:sortingType];

	[self.tableView reloadData];
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
		[alert show];
	}
}

#pragma mark - UIAlertViewDelegate functions

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	switch (alertView.tag)
    {
		case TAG_ALERT_CREATE_FOLDER:
        {
            NSString *folderName = [alertView textFieldAtIndex:0].text;
            if ((buttonIndex == alertView.firstOtherButtonIndex) &&
                (folderName != nil) &&
                (![folderName isEqualToString:@""]))
            {
				[self.delegate createFolder:folderName
                                     inFolder:self.currentFolder];
            }
			break;
        }
    }
}

#pragma mark - TextField Delegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	return NO;
}

#pragma mark - Tabbar buttons Methods

- (void)moveButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    if (self.delegate)
    {
        [self.delegate moveFiles:self.filesToMove
                          toPath:self.currentFolder
                    andOverwrite:YES];
    }
    
	if (self.delegate && [self.delegate respondsToSelector:@selector(backFromModalView:)])
    {
		[_delegate backFromModalView:NO];
    }
	[self.navigationController dismissViewControllerAnimated:YES
                                                  completion:nil];
}

- (void)copyButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    if (self.delegate)
    {
        [self.delegate copyFiles:self.filesToMove
                          toPath:self.currentFolder
                    andOverwrite:YES];
    }
    
	if (self.delegate && [self.delegate respondsToSelector:@selector(backFromModalView:)])
    {
		[self.delegate backFromModalView:NO];
    }
	[self.navigationController dismissViewControllerAnimated:YES
                                                  completion:nil];
}

- (void)cancelButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
	if( self.delegate && [self.delegate respondsToSelector:@selector(backFromModalView:)] )
		[self.delegate backFromModalView:NO];
	[self.navigationController dismissViewControllerAnimated:YES
                                                  completion:nil];
}

- (void)addFolderButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Create folder",nil)
                                                          message:nil
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"Cancel",nil)
                                                otherButtonTitles:NSLocalizedString(@"OK",nil), nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert setTag:TAG_ALERT_CREATE_FOLDER];
    [alert show];
}

#pragma mark - Rotating views:

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	// Return YES for supported orientations
	return YES;
}

@end
