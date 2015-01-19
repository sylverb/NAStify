//
//  FolderBrowserViewController.m
//  Synology DS
//
//  Created by Sylver Bruneau on 19/05/11.
//  Copyright 2011 Sylver Bruneau. All rights reserved.
//

#import "FolderBrowserViewController.h"
#import "ConnectionManager.h"
#import "FileItem.h"
#import "FileBrowserCell.h"

#define TAG_ALERT_CREATE_FOLDER 0

@implementation FolderBrowserViewController

#pragma mark - Initialization

- (id)initWithPath:(FileItem *)folder
{
    self = [super init];
	if (self)
    {
        self.currentFolder = folder;
		self.folderArray = [[NSMutableArray alloc] init];
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
	UIBarButtonItem *selectButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Select",@"")
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(selectButton:event:)];

    UIBarButtonItem *addFolderButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                         target:self
                                                                                         action:@selector(addFolderButton:event:)];
    addFolderButtonItem.style = UIBarButtonItemStylePlain;


	NSArray *buttons = [NSArray arrayWithObjects:flexibleSpaceButtonItem,selectButtonItem,flexibleSpaceButtonItem,addFolderButtonItem,flexibleSpaceButtonItem,nil];
    [self setToolbarItems:buttons];
    
	if ([title length] == 0) {
		title = @"/";
	}
    
	self.navigationItem.title = title;
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [self.navigationController.toolbar setTintColor:[UIColor blackColor]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setToolbarHidden:NO animated:YES];
    self.connectionManager.delegate = self;

	if ([self.folderArray count] == 0)
    {
		// Get file list
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
    static NSString * FileBrowserCellIdentifier = @"FileBrowserCell";
    
	FileItem *fileItem = (FileItem *)([self.folderArray objectAtIndex:indexPath.row]);
    
	FileBrowserCell *fileBrowserCell = (FileBrowserCell *)[tableView dequeueReusableCellWithIdentifier:FileBrowserCellIdentifier];
	if (fileBrowserCell == nil)
    {
		fileBrowserCell = [[FileBrowserCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                 reuseIdentifier:FileBrowserCellIdentifier];
	}

    // Configure the cell...
	[fileBrowserCell setFileItem:fileItem
					withDelegate:nil
						  andTag:0];
	
	return fileBrowserCell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	FileItem *folderItem = (FileItem *)([self.folderArray objectAtIndex:indexPath.row]);
	
	FolderBrowserViewController *folderBrowserViewController = [[FolderBrowserViewController alloc] initWithPath:folderItem];
    folderBrowserViewController.connectionManager = self.connectionManager;
    folderBrowserViewController.delegate = self.delegate;
    folderBrowserViewController.tag = self.tag;
	[self.navigationController pushViewController:folderBrowserViewController animated:YES];
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - CMDelegate Callbacks

- (void)CMFilesList:(NSDictionary *)dict
{
	NSArray *filesList = [dict objectForKey:@"filesList"];
	
	int i;
	[self.folderArray removeAllObjects];
	for (i=0; i<[filesList count];i++)
    {
        NSDictionary *element = [filesList objectAtIndex:i];
		if ([[element objectForKey:@"isdir"] boolValue])
        {
			FileItem *fileItem = [[FileItem alloc] init];
			fileItem.name = [element objectForKey:@"filename"];
            if ([self.currentFolder.path isEqualToString:@"/"])
            {
                fileItem.path = [NSString stringWithFormat:@"/%@",fileItem.name]; // Path to file
            }
            else
            {
                fileItem.path = [NSString stringWithFormat:@"%@/%@",self.currentFolder.path,fileItem.name]; // Path to file
            }
            
            if ([element objectForKey:@"path"])
            {
                fileItem.fullPath = [element objectForKey:@"path"]; // Path with filename/foldername
            }

            fileItem.isDir = YES;
            
            if ([element objectForKey:@"id"])
            {
                fileItem.objectIds = [self.currentFolder.objectIds arrayByAddingObject:[element objectForKey:@"id"]];
            }
            else
            {
                fileItem.objectIds = self.currentFolder.objectIds;
            }
            
			[self.folderArray addObject:fileItem];
		}
	}
	[self.tableView reloadData];
}

- (void)CMRootObject:(NSDictionary *)dict
{
    // This is used to replace the default root ID with the one retrieved here
    if ([dict objectForKey:@"rootId"])
    {
        self.currentFolder.objectIds = [NSArray arrayWithObject:[dict objectForKey:@"rootId"]];
    }
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

#pragma mark - Tabbar buttons Methods

- (void) selectButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    if (self.delegate != nil)
    {
        [self.delegate selectedFolderAtPath:self.currentFolder
                                     andTag:self.tag];
    }
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

@end
