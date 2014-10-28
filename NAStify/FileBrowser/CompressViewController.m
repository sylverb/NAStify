//
//  CompressViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "CompressViewController.h"
#import "TextButtonCell.h"
#import "SwitchCell.h"
#import "AltTextCell.h"

#define OVERWRITE_TAG 1
#define ARCHIVE_NAME_TAG 2
#define PASSWORD_TAG 3
#define ARCHIVE_TYPE_TAG 4
#define COMPRESSION_LEVEL_TAG 5

@implementation CompressViewController

#pragma mark - Initialization

- (id)init
{
	if ((self = [super init]))
    {
		self.files = nil;
		self.destFolder = nil;
		self.destArchiveName = @"default";
        self.destArchiveExtension = @"zip";
        self.password = nil;
        self.archiveTypes = [NSMutableArray array];
        self.archiveTypeExtensions = [NSMutableArray array];
        self.selectedTypeIndex = 0;
        self.compressionLevels = [NSArray arrayWithObjects:
                                  NSLocalizedString(@"Store",nil),
                                  NSLocalizedString(@"Fastest",nil),
                                  NSLocalizedString(@"Normal",nil),
                                  NSLocalizedString(@"Best",nil),
                                  nil];
        self.selectedCompressionLevelIndex = 2; // Default is "normal"
	}
	return self;
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
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
    UIBarButtonItem *compressButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Compress",nil)
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(compressButton:event:)];
	UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                      target:self
                                                                                      action:@selector(cancelButton:event:)];
    
    NSMutableArray *buttons = [NSMutableArray arrayWithCapacity:3];
    
    [buttons addObject:flexibleSpaceButtonItem];
    [buttons addObject:compressButtonItem];
	[buttons addObject:flexibleSpaceButtonItem];
	[buttons addObject:cancelButtonItem];
	[buttons addObject:flexibleSpaceButtonItem];
	[self setToolbarItems:buttons];
    
    self.navigationItem.title = NSLocalizedString(@"Compress Files", nil);
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [self.navigationController.toolbar setTintColor:[UIColor blackColor]];
    
    // Build supported archive type array
    if (ServerSupportsArchive(Zip))
    {
        [self.archiveTypes addObject:@"Zip"];
        [self.archiveTypeExtensions addObject:@"zip"];
    }
    if (ServerSupportsArchive(Rar))
    {
        [self.archiveTypes addObject:@"Rar"];
        [self.archiveTypeExtensions addObject:@"rar"];
    }
    if (ServerSupportsArchive(Tar))
    {
        [self.archiveTypes addObject:@"Tar"];
        [self.archiveTypeExtensions addObject:@"tar"];
    }
    if (ServerSupportsArchive(Gz))
    {
        [self.archiveTypes addObject:@"Gz"];
        [self.archiveTypeExtensions addObject:@"gz"];
    }
    if (ServerSupportsArchive(Bz2))
    {
        [self.archiveTypes addObject:@"Bz2"];
        [self.archiveTypeExtensions addObject:@"bz2"];
    }
    if (ServerSupportsArchive(7z))
    {
        [self.archiveTypes addObject:@"7z"];
        [self.archiveTypeExtensions addObject:@"7z"];
    }
    if (ServerSupportsArchive(Ace))
    {
        [self.archiveTypes addObject:@"Ace"];
        [self.archiveTypeExtensions addObject:@"ace"];
    }
    if (ServerSupportsArchive(TarGz))
    {
        [self.archiveTypes addObject:@"Tar/Gzip"];
        [self.archiveTypeExtensions addObject:@"tar.gz"];
    }
    if (ServerSupportsArchive(TarBz2))
    {
        [self.archiveTypes addObject:@"Tar/Bz2"];
        [self.archiveTypeExtensions addObject:@"tar.bz2"];
    }
    if (ServerSupportsArchive(TarXz))
    {
        [self.archiveTypes addObject:@"Tar/Xz"];
        [self.archiveTypeExtensions addObject:@"tar.xz"];
    }
    if (ServerSupportsArchive(TarLzma))
    {
        [self.archiveTypes addObject:@"Tar/Lzma"];
        [self.archiveTypeExtensions addObject:@"tar.lzma"];
    }
    if (ServerSupportsArchive(Cpio))
    {
        [self.archiveTypes addObject:@"Cpio"];
        [self.archiveTypeExtensions addObject:@"cpio"];
    }
    if (ServerSupportsArchive(CpioGz))
    {
        [self.archiveTypes addObject:@"Cpio/Gz"];
        [self.archiveTypeExtensions addObject:@"cpio.gz"];
    }
    if (ServerSupportsArchive(CpioBz2))
    {
        [self.archiveTypes addObject:@"Cpio/Bz2"];
        [self.archiveTypeExtensions addObject:@"cpio.bz2"];
    }
    if (ServerSupportsArchive(CpioXz))
    {
        [self.archiveTypes addObject:@"Cpio/Xz"];
        [self.archiveTypeExtensions addObject:@"cpio.xz"];
    }
    if (ServerSupportsArchive(CpioLzma))
    {
        [self.archiveTypes addObject:@"Cpio/Lzma"];
        [self.archiveTypeExtensions addObject:@"cpio.lzma"];
    }
    if (ServerSupportsArchive(Iso9660))
    {
        [self.archiveTypes addObject:@"Iso9660"];
        [self.archiveTypeExtensions addObject:@"iso"];
    }
    
    // Set archive extension regarding the selected archive type
    self.destArchiveExtension = [self.archiveTypeExtensions objectAtIndex:self.selectedTypeIndex];
}

- (void)viewWillAppear:(BOOL)animated
{
	[self.navigationController setToolbarHidden:NO animated:NO];
    
    [super viewWillAppear:animated];
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    NSInteger numberOfRows = 5;
    if ([self.archiveTypes count] > 1)
    {
        numberOfRows = 6;
    }

    return numberOfRows;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *TextButtonCellIdentifier = @"TextButtonCell";
	static NSString *AltTextCellIdentifier = @"AltTextCell";
    static NSString *SwitchCellIdentifier = @"SwitchCell";
	
	UITableViewCell *cell = nil;
	switch (indexPath.section)
    {
		case 0:
		{
			switch (indexPath.row)
            {
				case 0:
                {
                    TextButtonCell *textButtonCell = (TextButtonCell *)[tableView dequeueReusableCellWithIdentifier:TextButtonCellIdentifier];
                    if (textButtonCell == nil)
                    {
                        textButtonCell = [[TextButtonCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                               reuseIdentifier:TextButtonCellIdentifier];
                    }
                    
                    [textButtonCell setCellDataWithLabelString:NSLocalizedString(@"Destination Folder:",nil)
                                                      withText:self.destFolder.path
                                                        andTag:0];
                    [textButtonCell.textButton addTarget:self action:@selector(destFolder:) forControlEvents:UIControlEventTouchUpInside];
                    
                    cell = textButtonCell;
                    
					break;
                }
                case 1:
                {
                    AltTextCell *textCell = (AltTextCell *)[tableView dequeueReusableCellWithIdentifier:AltTextCellIdentifier];
                    if (textCell == nil)
                    {
                        textCell = [[AltTextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:AltTextCellIdentifier];
                    }
                    
                    [textCell.textField setInputAccessoryView:nil];
                    
                    UIToolbar *toolbar = [[UIToolbar alloc] init];
                    [toolbar setBarStyle:UIBarStyleBlackTranslucent];
                    [toolbar sizeToFit];
                    
                    UIBarButtonItem *flexButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                                target:self
                                                                                                action:nil];
                    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                                target:self
                                                                                                action:@selector(resignKeyboard:)];
                    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                                  target:self
                                                                                                  action:@selector(cancelKeyboardEntry:)];
                    NSArray *itemsArray = [NSArray arrayWithObjects:cancelButton,flexButton, doneButton, nil];
                    
                    [toolbar setItems:itemsArray];
                    
                    [textCell.textField setInputAccessoryView:toolbar];
                    
                    self.editedCell = textCell;


                    [textCell setCellDataWithLabelString:NSLocalizedString(@"Archive name:",nil)
                                                withText:[NSString stringWithFormat:@"%@.%@", self.destArchiveName, self.destArchiveExtension]
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeDefault
                                            withDelegate:self
                                                  andTag:ARCHIVE_NAME_TAG];
                    
                    cell = textCell;
                    
                    break;
                }
                case 2:
                {
                    AltTextCell *textCell = (AltTextCell *)[tableView dequeueReusableCellWithIdentifier:AltTextCellIdentifier];
                    if (textCell == nil)
                    {
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
                case 3:
                {
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil)
                    {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell setCellDataWithLabelString:NSLocalizedString(@"Overwrite file:",nil)
                                                 withState:self.overwrite
                                                    andTag:OVERWRITE_TAG];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
                    
                    break;
                }
				case 4:
                {
                    TextButtonCell *textButtonCell = (TextButtonCell *)[tableView dequeueReusableCellWithIdentifier:TextButtonCellIdentifier];
                    if (textButtonCell == nil)
                    {
                        textButtonCell = [[TextButtonCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                               reuseIdentifier:TextButtonCellIdentifier];
                    }
                    
                    [textButtonCell setCellDataWithLabelString:NSLocalizedString(@"Compression level:",nil)
                                                      withText:[self.compressionLevels objectAtIndex:self.selectedCompressionLevelIndex]
                                                        andTag:0];
                    [textButtonCell.textButton addTarget:self
                                                  action:@selector(selectCompressionLevel:)
                                        forControlEvents:UIControlEventTouchUpInside];
                    
                    cell = textButtonCell;
                    
					break;
                }
				case 5:
                {
                    TextButtonCell *textButtonCell = (TextButtonCell *)[tableView dequeueReusableCellWithIdentifier:TextButtonCellIdentifier];
                    if (textButtonCell == nil)
                    {
                        textButtonCell = [[TextButtonCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                               reuseIdentifier:TextButtonCellIdentifier];
                    }
                    
                    [textButtonCell setCellDataWithLabelString:NSLocalizedString(@"Select type:",nil)
                                                      withText:[self.archiveTypes objectAtIndex:self.selectedTypeIndex]
                                                        andTag:0];
                    [textButtonCell.textButton addTarget:self
                                                  action:@selector(selectType:)
                                        forControlEvents:UIControlEventTouchUpInside];
                    
                    cell = textButtonCell;
                    
					break;
                }
			}
			break;
		}
    }
    
	return cell;
}

#pragma mark - Tabbar buttons Methods

- (void)compressButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    ARCHIVE_TYPE type = ARCHIVE_TYPE_ZIP;
    NSString *archiveTypeString = [self.archiveTypes objectAtIndex:self.selectedTypeIndex];
    if ([archiveTypeString isEqualToString:@"Rar"])
    {
        type = ARCHIVE_TYPE_RAR;
    }
    else if ([archiveTypeString isEqualToString:@"Tar"])
    {
        type = ARCHIVE_TYPE_TAR;
    }
    else if ([archiveTypeString isEqualToString:@"Gz"])
    {
        type = ARCHIVE_TYPE_GZ;
    }
    else if ([archiveTypeString isEqualToString:@"Bz2"])
    {
        type = ARCHIVE_TYPE_BZ2;
    }
    else if ([archiveTypeString isEqualToString:@"7z"])
    {
        type = ARCHIVE_TYPE_7Z;
    }
    else if ([archiveTypeString isEqualToString:@"Ace"])
    {
        type = ARCHIVE_TYPE_ACE;
    }

    ARCHIVE_COMPRESSION_LEVEL compressionLevel;
    switch (self.selectedCompressionLevelIndex)
    {
        case 0:
        {
            compressionLevel = ARCHIVE_COMPRESSION_LEVEL_NONE;
            break;
        }
        case 1:
        {
            compressionLevel = ARCHIVE_COMPRESSION_LEVEL_FASTEST;
            break;
        }
        case 2:
        {
            compressionLevel = ARCHIVE_COMPRESSION_LEVEL_NORMAL;
            break;
        }
        case 3:
        {
            compressionLevel = ARCHIVE_COMPRESSION_LEVEL_BEST;
            break;
        }
        default:
        {
            compressionLevel = ARCHIVE_COMPRESSION_LEVEL_NORMAL;
            break;
        }
    }
    
    if (self.delegate)
    {
        [self.delegate compressFiles:self.files
                           toArchive:[NSString stringWithFormat:@"%@/%@.%@",self.destFolder.path,self.destArchiveName,self.destArchiveExtension]
                         archiveType:type
                    compressionLevel:compressionLevel
                            password:self.password
                           overwrite:YES];
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

- (void)selectType:(UIButton *)button
{
    TableSelectViewController *tableSelectViewController;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStylePlain];
    }
    else
    {
        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStyleGrouped];
    }
    tableSelectViewController.elements = self.archiveTypes;
    tableSelectViewController.selectedElement = self.selectedTypeIndex;
    tableSelectViewController.delegate = self;
    tableSelectViewController.tag = ARCHIVE_TYPE_TAG;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        CGRect rect = button.frame;
        self.archiveTypePopoverController = [[UIPopoverController alloc] initWithContentViewController:tableSelectViewController];
        self.archiveTypePopoverController.popoverContentSize = CGSizeMake(320.0, MIN([self.archiveTypes count] * 44.0,700));
        [self.archiveTypePopoverController presentPopoverFromRect:rect
                                                           inView:button.superview
                                         permittedArrowDirections:UIPopoverArrowDirectionDown|UIPopoverArrowDirectionUp|UIPopoverArrowDirectionRight
                                                         animated:YES];
    }
    else
    {
        [self presentViewController:tableSelectViewController animated:YES completion:nil];
    }
}

- (void)selectCompressionLevel:(UIButton *)button
{
    TableSelectViewController *tableSelectViewController;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStylePlain];
    }
    else
    {
        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStyleGrouped];
    }
    tableSelectViewController.elements = self.compressionLevels;
    tableSelectViewController.selectedElement = self.selectedCompressionLevelIndex;
    tableSelectViewController.delegate = self;
    tableSelectViewController.tag = COMPRESSION_LEVEL_TAG;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        CGRect rect = button.frame;
        self.compressionLevelPopoverController = [[UIPopoverController alloc] initWithContentViewController:tableSelectViewController];
        self.compressionLevelPopoverController.popoverContentSize = CGSizeMake(320.0, MIN([self.compressionLevels count] * 44.0,700));
        [self.compressionLevelPopoverController presentPopoverFromRect:rect
                                                           inView:button.superview
                                         permittedArrowDirections:UIPopoverArrowDirectionDown|UIPopoverArrowDirectionUp|UIPopoverArrowDirectionRight
                                                         animated:YES];
    }
    else
    {
        [self presentViewController:tableSelectViewController animated:YES completion:nil];
    }
}

#pragma mark - TableSelectViewController Delegate

- (void)selectedElementIndex:(NSInteger)elementIndex forTag:(NSInteger)tag
{
    switch (tag)
    {
        case ARCHIVE_TYPE_TAG:
        {
            if (self.archiveTypePopoverController.popoverVisible)
            {
                [self.archiveTypePopoverController dismissPopoverAnimated:YES];
                self.archiveTypePopoverController = nil;
            }
            
            self.selectedTypeIndex = elementIndex;
            
            // Update archive extension
            self.destArchiveExtension = [self.archiveTypeExtensions objectAtIndex:self.selectedTypeIndex];

            [self.tableView reloadData];
            break;
        }
        case COMPRESSION_LEVEL_TAG:
        {
            if (self.compressionLevelPopoverController.popoverVisible)
            {
                [self.compressionLevelPopoverController dismissPopoverAnimated:YES];
                self.compressionLevelPopoverController = nil;
            }
            
            self.selectedCompressionLevelIndex = elementIndex;
            [self.tableView reloadData];
        }
        default:
        {
            break;
        }
    }
}

#pragma mark - UITextField/UISwitch/UISlider responders

- (void)cancelKeyboardEntry:(UIBarButtonItem *)button
{
    // Restore previous name and make keyboard disappear
    self.editedCell.textField.text = [NSString stringWithFormat:@"%@.%@",self.destArchiveName,self.destArchiveExtension];
    
    [self.editedCell.textField resignFirstResponder];
    
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
    [self textFieldShouldReturn:self.editedCell.textField];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSString *fileName = [textField.text lastPathComponent];
    NSArray *fileElements =[fileName componentsSeparatedByString:@"."];
    BOOL extensionFound = NO;
    if ([fileElements count] > 2)
    {
        // Check for multiple & single element archive extension
        // Create virtual extension
        NSString *extension = [NSString stringWithFormat:@"%@.%@",[fileElements objectAtIndex:[fileElements count]-2],[fileElements lastObject]];
        NSInteger index = 0;
        for (index = 0; index < [self.archiveTypeExtensions count]; index++)
        {
            if ([extension isEqualToString:[self.archiveTypeExtensions objectAtIndex:index]])
            {
                extensionFound = YES;
                break;
            }
        }
    }
    if (([fileElements count] >= 2) && (extensionFound == NO))
    {
        // Check for single element archive extension
        NSString *extension = [fileElements lastObject];
        NSInteger index = 0;
        for (index = 0; index < [self.archiveTypeExtensions count]; index++)
        {
            if ([extension isEqualToString:[self.archiveTypeExtensions objectAtIndex:index]])
            {
                extensionFound = YES;
                break;
            }
        }
    }

    if (extensionFound == YES)
    {
        [textField resignFirstResponder];
        return YES;
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil)
                                                        message:NSLocalizedString(@"Invalid archive extension",nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK",nil)
                                              otherButtonTitles:nil];
        [alert show];
        return NO;
    }
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
        case ARCHIVE_NAME_TAG:
        {
            NSString *fileName = [textField.text lastPathComponent];
            NSArray *fileElements =[fileName componentsSeparatedByString:@"."];
            BOOL extensionFound = NO;
            if ([fileElements count] > 2)
            {
                // Check for multiple & single element archive extension
                // Create virtual extension
                NSString *extension = [NSString stringWithFormat:@"%@.%@",[fileElements objectAtIndex:[fileElements count]-2],[fileElements lastObject]];
                NSInteger index = 0;
                for (index = 0; index < [self.archiveTypeExtensions count]; index++)
                {
                    if ([extension isEqualToString:[self.archiveTypeExtensions objectAtIndex:index]])
                    {
                        self.selectedTypeIndex = index;
                        self.destArchiveExtension = extension;
                        
                        self.destArchiveName = [textField.text substringToIndex:[textField.text length] - [extension length] - 1];
                        extensionFound = YES;
                        break;
                    }
                }
            }
            if (([fileElements count] >= 2) && (extensionFound == NO))
            {
                // Check for single element archive extension
                NSString *extension = [fileElements lastObject];
                NSInteger index = 0;
                for (index = 0; index < [self.archiveTypeExtensions count]; index++)
                {
                    if ([extension isEqualToString:[self.archiveTypeExtensions objectAtIndex:index]])
                    {
                        self.selectedTypeIndex = index;
                        self.destArchiveExtension = extension;
                        
                        self.destArchiveName = [textField.text substringToIndex:[textField.text length] - [extension length] - 1];
                        break;
                    }
                }
            }
			[self.tableView reloadData];
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

#pragma mark - FolderBrowserViewControllerDelegate

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

#pragma mark - Rotating views:

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// Return YES for supported orientations
	return YES;
}

@end
