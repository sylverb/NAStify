//
//  ExtractViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ExtractViewController.h"
#import "TextButtonCell.h"
#import "SwitchCell.h"
#import "AltTextCell.h"

#define OVERWRITE_TAG 1
#define EXTRACTWITHFOLDERS_TAG 2
#define PASSWORD_TAG 3

@implementation ExtractViewController

#pragma mark - Initialization

- (id)init
{
	if ((self = [super init]))
    {
		self.files = nil;
		self.destFolder = nil;
        self.password = nil;
		self.folderArray = [[NSMutableArray alloc] init];
        self.overwrite = NO;
        self.extractWithFolders = YES;
	}
	return self;
}


#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.edgesForExtendedLayout = UIRectEdgeNone;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight |
                                      UIViewAutoresizingFlexibleBottomMargin;

    [self.view addSubview:self.tableView];
    
	UIBarButtonItem *flexibleSpaceButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                             target:nil
                                                                                             action:nil];
    UIBarButtonItem *extractButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Extract",nil)
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(extractButton:event:)];
	UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButton:event:)];
    
    NSMutableArray *buttons = [NSMutableArray arrayWithCapacity:3];
    
    [buttons addObject:flexibleSpaceButtonItem];
    [buttons addObject:extractButtonItem];
	[buttons addObject:flexibleSpaceButtonItem];
	[buttons addObject:cancelButtonItem];
	[buttons addObject:flexibleSpaceButtonItem];
	[self setToolbarItems:buttons];
    
    if ([self.files count] > 1)
    {
        self.navigationItem.title = @"Extract files";
    }
    else
    {
        FileItem *file = [self.files firstObject];
        self.navigationItem.title = [NSString stringWithFormat:@"Extract %@", file.name];
    }
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [self.navigationController.toolbar setTintColor:[UIColor blackColor]];
}

- (void)viewWillAppear:(BOOL)animated
{
	[self.navigationController setToolbarHidden:NO animated:NO];
	
    [super viewWillAppear:animated];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 4;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *TextButtonCellIdentifier = @"TextButtonCell";
	static NSString *AltTextCellIdentifier = @"AltTextCell";
    static NSString *SwitchCellIdentifier = @"SwitchCell";
	
	UITableViewCell *cell = nil;
	switch (indexPath.section) {
		case 0:
		{
			switch (indexPath.row) {
				case 0:
                {
                    TextButtonCell *textButtonCell = (TextButtonCell *)[tableView dequeueReusableCellWithIdentifier:TextButtonCellIdentifier];
                    if (textButtonCell == nil) {
                        textButtonCell = [[TextButtonCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                               reuseIdentifier:TextButtonCellIdentifier];
                    }
                    
                    [textButtonCell setCellDataWithLabelString:NSLocalizedString(@"Destination Folder:",nil)
                                                      withText:self.destFolder.path
                                                        andTag:0];
                    // Allow dest folder selection only if there is one archive to extract
                    if ([self.files count] == 1)
                    {
                        [textButtonCell.textButton addTarget:self action:@selector(destFolder:) forControlEvents:UIControlEventTouchUpInside];
                    }
                    
                    cell = textButtonCell;
                    
					break;
                }
                case 1:
                {
                    AltTextCell *textCell = (AltTextCell *)[tableView dequeueReusableCellWithIdentifier:AltTextCellIdentifier];
                    if (textCell == nil) {
                        textCell = [[AltTextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:AltTextCellIdentifier];
                    }
                    
                    [textCell setCellDataWithLabelString:NSLocalizedString(@"Password:",nil)
                                                withText:self.password
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeDefault
                                            withDelegate:self
                                                  andTag:PASSWORD_TAG];
                    
                    cell = textCell;
                    
                    break;
                }
                case 2:
                {
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil) {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell setCellDataWithLabelString:NSLocalizedString(@"Overwrite files:",nil)
                                                 withState:self.overwrite
                                                    andTag:OVERWRITE_TAG];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
                    
                    break;
                }
                case 3:
                {
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil) {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell setCellDataWithLabelString:NSLocalizedString(@"Extract with folders:",nil)
                                                 withState:self.extractWithFolders
                                                    andTag:EXTRACTWITHFOLDERS_TAG];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
                    
                    break;
                }
			}
			break;
		}
    }
    
	return cell;
}

#pragma mark - Tabbar buttons Methods

- (void)extractButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    if (self.delegate)
    {
        [self.delegate extractFiles:self.files
                           toFolder:self.destFolder
                       withPassword:self.password
                          overwrite:self.overwrite
                  extractWithFolder:self.extractWithFolders];
    }
    
	if(self.delegate && [self.delegate respondsToSelector:@selector(backFromModalView:)])
    {
		[self.delegate backFromModalView:NO];
    }
	[self.navigationController dismissViewControllerAnimated:YES
                                                  completion:nil];
}

- (void)cancelButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
	if(self.delegate && [self.delegate respondsToSelector:@selector(backFromModalView:)])
    {
		[self.delegate backFromModalView:NO];
    }
	[self.navigationController dismissViewControllerAnimated:YES
                                                  completion:nil];
}

#pragma mark - UITextField/UISwitch/UISlider responders

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	switch (textField.tag)
    {
		case PASSWORD_TAG:
		{
            self.password = textField.text;
			break;
		}
	}
}

- (void)switchValueChanged:(id)sender
{
	NSInteger tag = ((UISwitch *)sender).tag;
	switch (tag)
    {
		case OVERWRITE_TAG:
        {
			self.overwrite = [sender isOn];
			[self.tableView reloadData];
			break;
        }
		case EXTRACTWITHFOLDERS_TAG:
        {
			self.extractWithFolders = [sender isOn];
			[self.tableView reloadData];
			break;
        }
	}
}

- (void)destFolder:(UIButton *)button
{
    if (self.destPopoverController.popoverVisible)
    {
        [self.destPopoverController dismissPopoverAnimated:YES];
        self.destPopoverController = nil;
    }
    else
    {
        NSMutableArray *pathArray;
        if ([self.destFolder.path isEqual:@"/"])
        {
            pathArray = [NSMutableArray arrayWithObject:@""];
        }
        else
        {
            pathArray = [NSMutableArray arrayWithArray:[self.destFolder.path componentsSeparatedByString:@"/"]];
        }
        
        NSMutableArray *fullPathArray;
        if ([self.destFolder.fullPath isEqual:@"/"])
        {
            fullPathArray = [NSMutableArray arrayWithObject:@""];
        }
        else
        {
            fullPathArray = [NSMutableArray arrayWithArray:[self.destFolder.fullPath componentsSeparatedByString:@"/"]];
        }
        
        NSMutableArray *objectIds = nil;
        if (self.destFolder.objectIds != nil)
        {
            objectIds = [NSMutableArray arrayWithArray:self.destFolder.objectIds];
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
        UINavigationController *folderNavController = [[UINavigationController alloc] init];
        
        for (FileItem *folder in folderItems)
        {
            FolderBrowserViewController *folderBrowserViewController = [[FolderBrowserViewController alloc] initWithPath:folder];
            folderBrowserViewController.delegate = self;
            folderBrowserViewController.connectionManager = self.connectionManager;
            folderBrowserViewController.title = folder.path;
            
            [folderNavController pushViewController:folderBrowserViewController animated:NO];
        }
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            
            UITableViewCell *superTableCell = (UITableViewCell *)button.superview;
            // Get y values from the tablecell and x values from the button frame
            CGRect rect = superTableCell.frame;
            rect.origin.x = button.frame.origin.x;
            rect.size.width = button.frame.size.width;
            
            self.destPopoverController = [[UIPopoverController alloc] initWithContentViewController:folderNavController];
            [self.destPopoverController presentPopoverFromRect:rect
                                                        inView:self.view
                                      permittedArrowDirections:UIPopoverArrowDirectionDown|UIPopoverArrowDirectionUp
                                                      animated:YES];
        }
        else
        {
            [self presentViewController:folderNavController animated:YES completion:nil];
        }
    }
}

#pragma mark -
#pragma mark FolderBrowserViewControllerDelegate

- (void)selectedFolderAtPath:(FileItem *)folder andTag:(NSInteger)tag
{
    if (self.destPopoverController.popoverVisible)
    {
        [self.destPopoverController dismissPopoverAnimated:YES];
        self.destPopoverController = nil;
    }
    self.destFolder = folder;
    
    // Refresh folder value
    [self.tableView reloadData];
}

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder
{
    [self.delegate createFolder:folderName inFolder:folder];
}

#pragma mark -
#pragma mark Rotating views:

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// Return YES for supported orientations
	return YES;
}

@end
