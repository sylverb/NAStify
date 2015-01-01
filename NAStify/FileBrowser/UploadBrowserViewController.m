//
//  UploadBrowserViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright 2014 CodeIsALie. All rights reserved.
//

#import "UploadBrowserViewController.h"
#import "ConnectionManager.h"
#import "FileItem.h"
#import "FileBrowserCell.h"

@implementation UploadBrowserViewController
@synthesize tag;

#pragma mark - Initialization

- (id)init
{
    self = [super init];
	if (self)
    {
		self.filesArray = [[NSMutableArray alloc] init];
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
    UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                         target:self
                                                                         action:@selector(cancelButton:event:)];

	NSArray *buttons = [NSArray arrayWithObjects:flexibleSpaceButtonItem,cancelButtonItem,flexibleSpaceButtonItem,nil];
    [self setToolbarItems:buttons];
    
	if ([title length] == 0) {
		title = @"/";
	}
    
	self.navigationItem.title = title;
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [self.navigationController.toolbar setTintColor:[UIColor blackColor]];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.navigationController setToolbarHidden:NO animated:YES];
    self.connectionManager.delegate = self;

	if ([self.filesArray count] == 0) {
		// Get file list
		[self.connectionManager listForPath:self.currentFolder];
	}
    
    [super viewWillAppear:animated];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self.filesArray count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * FileBrowserCellIdentifier = @"FileBrowserCell";
    
	FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);
    
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:indexPath.row]);
    
    if (fileItem.isDir)
    {
        UploadBrowserViewController *uploadBrowserViewController = [[UploadBrowserViewController alloc] init];
        uploadBrowserViewController.connectionManager = self.connectionManager;
        uploadBrowserViewController.delegate = self.delegate;
        uploadBrowserViewController.currentFolder = fileItem;
        uploadBrowserViewController.tag = self.tag;
        [self.navigationController pushViewController:uploadBrowserViewController animated:YES];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Upload file",nil)
                                                        message:fileItem.name
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel",nil)
                                              otherButtonTitles:NSLocalizedString(@"OK",nil), nil];
        [alert setTag:indexPath.row];
        [alert show];
    }
    
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - CMDelegate Callbacks

- (void)CMFilesList:(NSDictionary *)dict
{
    // Check if the notification is for this folder
    if ((([dict objectForKey:@"path"]) && ([self.currentFolder.path isEqualToString:[dict objectForKey:@"path"]])) ||
        (([dict objectForKey:@"id"]) && ([[self.currentFolder.objectIds lastObject] isEqualToString:[dict objectForKey:@"id"]])))
    {
        if ([[dict objectForKey:@"success"] boolValue])
        {
            NSArray *filesList = [dict objectForKey:@"filesList"];
            
            [self.filesArray removeAllObjects];
            
            int i;
            for (i=0; i<[filesList count]; i++)
            {
                FileItem *fileItem = [[FileItem alloc] init];
                fileItem.name = [[filesList objectAtIndex:i] objectForKey:@"filename"];
                fileItem.isDir = [[[filesList objectAtIndex:i] objectForKey:@"isdir"] boolValue];
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
                if (([[filesList objectAtIndex:i] objectForKey:@"date"]) &&
                    ([[[filesList objectAtIndex:i] objectForKey:@"date"] doubleValue] != 0))
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
            [self.filesArray sortFileItemArrayWithOrder:SORT_BY_NAME_DESC_FOLDER_FIRST];
            
            // Refresh tableView
            [self.tableView reloadData];
        }
        else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Browse",nil)
                                                            message:NSLocalizedString([dict objectForKey:@"error"],nil)
                                                           delegate:nil
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
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

#pragma mark - UIAlertViewDelegate functions

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == [alertView cancelButtonIndex])
    {
        // do nothing
    }
    else
    {
        FileItem *fileItem = (FileItem *)([self.filesArray objectAtIndex:alertView.tag]);
        [self.delegate uploadFile:fileItem];
        [self.navigationController dismissViewControllerAnimated:YES
                                                      completion:nil];
    }
}

#pragma mark - Tabbar buttons Methods

- (void) cancelButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
	[self.navigationController dismissViewControllerAnimated:YES
                                                  completion:nil];
}

@end
