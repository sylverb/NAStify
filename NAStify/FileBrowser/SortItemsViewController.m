//
//  ExtractViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "SortItemsViewController.h"
#import "TextButtonCell.h"
#import "SwitchCell.h"
#import "AltTextCell.h"
#import "SegCtrlCell.h"

#define TAG_SORTING_TYPE 1
#define TAG_FOLDER_FIRST 2
#define TAG_ASC_DESC 3

@implementation SortItemsViewController

#pragma mark - Initialization

- (id)initWithSortingType:(FileItemSortType)sortingType {
	if ((self = [super init]))
    {
        self.foldersFirst = NO;
        switch (sortingType)
        {
            case SORT_BY_NAME_DESC_FOLDER_FIRST:
            {
                self.selectedSortingOptionIndex = 0;
                self.foldersFirst = YES;
                self.descending = YES;
                break;
            }
            case SORT_BY_NAME_DESC:
            {
                self.selectedSortingOptionIndex = 0;
                self.foldersFirst = NO;
                self.descending = YES;
                break;
            }
            case SORT_BY_NAME_ASC_FOLDER_FIRST:
            {
                self.selectedSortingOptionIndex = 0;
                self.foldersFirst = YES;
                self.descending = NO;
                break;
            }
            case SORT_BY_NAME_ASC:
            {
                self.selectedSortingOptionIndex = 0;
                self.foldersFirst = NO;
                self.descending = NO;
                break;
            }
            case SORT_BY_DATE_DESC_FOLDER_FIRST:
            {
                self.selectedSortingOptionIndex = 1;
                self.foldersFirst = YES;
                self.descending = YES;
                break;
            }
            case SORT_BY_DATE_DESC:
            {
                self.selectedSortingOptionIndex = 1;
                self.foldersFirst = NO;
                self.descending = YES;
                break;
            }
            case SORT_BY_DATE_ASC_FOLDER_FIRST:
            {
                self.selectedSortingOptionIndex = 1;
                self.foldersFirst = YES;
                self.descending = NO;
                break;
            }
            case SORT_BY_DATE_ASC:
            {
                self.selectedSortingOptionIndex = 1;
                self.foldersFirst = NO;
                self.descending = NO;
                break;
            }
            case SORT_BY_TYPE_DESC_FOLDER_FIRST:
            {
                self.selectedSortingOptionIndex = 2;
                self.foldersFirst = YES;
                self.descending = YES;
                break;
            }
            case SORT_BY_TYPE_DESC:
            {
                self.selectedSortingOptionIndex = 2;
                self.foldersFirst = NO;
                self.descending = YES;
                break;
            }
            case SORT_BY_TYPE_ASC_FOLDER_FIRST:
            {
                self.selectedSortingOptionIndex = 2;
                self.foldersFirst = YES;
                self.descending = NO;
                break;
            }
            case SORT_BY_TYPE_ASC:
            {
                self.selectedSortingOptionIndex = 2;
                self.foldersFirst = NO;
                self.descending = NO;
                break;
            }
            case SORT_BY_SIZE_DESC_FOLDER_FIRST:
            {
                self.selectedSortingOptionIndex = 3;
                self.foldersFirst = YES;
                self.descending = YES;
                break;
            }
            case SORT_BY_SIZE_DESC:
            {
                self.selectedSortingOptionIndex = 3;
                self.foldersFirst = NO;
                self.descending = YES;
                break;
            }
            case SORT_BY_SIZE_ASC_FOLDER_FIRST:
            {
                self.selectedSortingOptionIndex = 3;
                self.foldersFirst = YES;
                self.descending = NO;
                break;
            }
            case SORT_BY_SIZE_ASC:
            {
                self.selectedSortingOptionIndex = 3;
                self.foldersFirst = NO;
                self.descending = NO;
                break;
            }
            default:
            {
                break;
            }
        }
	}
	return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
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
    UIBarButtonItem *applyButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Apply",@"")
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(applyButton:event:)];
	UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                      target:self
                                                                                      action:@selector(cancelButton:event:)];
    
    NSArray *buttons = [NSArray arrayWithObjects:flexibleSpaceButtonItem, applyButtonItem, flexibleSpaceButtonItem, cancelButtonItem, flexibleSpaceButtonItem, nil];
    
	[self setToolbarItems:buttons];
    
    self.navigationItem.title = NSLocalizedString(@"Sorting options", nil);
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [self.navigationController.toolbar setTintColor:[UIColor blackColor]];
    
    self.sortingOptions = [NSArray arrayWithObjects:
                           NSLocalizedString(@"name", nil),
                           NSLocalizedString(@"date", nil),
                           NSLocalizedString(@"type", nil),
                           NSLocalizedString(@"size", nil),
                           nil];
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
    return 3;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *TextButtonCellIdentifier = @"TextButtonCell";
    static NSString *SwitchCellIdentifier = @"SwitchCell";
    static NSString *SegmentedControllerCellIdentifier = @"SegmentedControllerCell";
	
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
                    [textButtonCell setCellDataWithLabelString:NSLocalizedString(@"Sorting by:",@"")
                                                      withText:[self.sortingOptions objectAtIndex:self.selectedSortingOptionIndex]
                                                        andTag:0];
                    [textButtonCell.textButton addTarget:self
                                                  action:@selector(selectSortingType:)
                                        forControlEvents:UIControlEventTouchUpInside];
                    
                    cell = textButtonCell;
                    
					break;
                }
                case 1:
                {
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil) {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell setCellDataWithLabelString:NSLocalizedString(@"Folders first:",@"")
                                                 withState:self.foldersFirst
                                                    andTag:TAG_FOLDER_FIRST];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
                    
                    break;
                }
                case 2:
                {
                    NSInteger selectedIndex = 0;
                    SegCtrlCell *segCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedControllerCellIdentifier];
                    if (segCtrlCell == nil)
                    {
                        segCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:SegmentedControllerCellIdentifier];
                    }
                    
                    if (self.descending)
                    {
                        selectedIndex = 1;
                    }
                    else
                    {
                        selectedIndex = 0;
                    }
                    
                    
                    [segCtrlCell setCellDataWithLabelString:NSLocalizedString(@"Order :",@"")
                                          withSelectedIndex:selectedIndex
                                                     andTag:TAG_ASC_DESC];
                    
                    [segCtrlCell.segmentedControl addTarget:self action:@selector(segmentedValueChanged:) forControlEvents:UIControlEventValueChanged];
                    
                    cell = segCtrlCell;

                    break;
                }
			}
			break;
		}
    }
    
	return cell;
}

- (void)selectSortingType:(UIButton *)button
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
    tableSelectViewController.elements = self.sortingOptions;
    tableSelectViewController.selectedElement = self.selectedSortingOptionIndex;
    tableSelectViewController.delegate = self;
    tableSelectViewController.tag = TAG_SORTING_TYPE;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        CGRect rect = button.frame;
        self.sortingOptionPopoverController = [[UIPopoverController alloc] initWithContentViewController:tableSelectViewController];
        self.sortingOptionPopoverController.popoverContentSize = CGSizeMake(320.0, MIN([self.sortingOptions count] * 44.0,700));
        [self.sortingOptionPopoverController presentPopoverFromRect:rect
                                                             inView:button.superview
                                           permittedArrowDirections:UIPopoverArrowDirectionDown|UIPopoverArrowDirectionUp|UIPopoverArrowDirectionRight
                                                           animated:YES];
    }
    else
    {
        [self presentViewController:tableSelectViewController animated:YES completion:nil];
    }
}

#pragma mark - Tabbar buttons Methods

- (void) applyButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    FileItemSortType selectedSorting;
    switch (self.selectedSortingOptionIndex)
    {
        case 0: // name
        {
            if (self.foldersFirst)
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_NAME_DESC_FOLDER_FIRST;
                }
                else
                {
                    selectedSorting = SORT_BY_NAME_ASC_FOLDER_FIRST;
                }
            }
            else
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_NAME_DESC;
                }
                else
                {
                    selectedSorting = SORT_BY_NAME_ASC;
                }
            }
            break;
        }
        case 1: // date
        {
            if (self.foldersFirst)
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_DATE_DESC_FOLDER_FIRST;
                }
                else
                {
                    selectedSorting = SORT_BY_DATE_ASC_FOLDER_FIRST;
                }
            }
            else
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_DATE_DESC;
                }
                else
                {
                    selectedSorting = SORT_BY_DATE_ASC;
                }
            }
            break;
        }
        case 2: // type
        {
            if (self.foldersFirst)
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_TYPE_DESC_FOLDER_FIRST;
                }
                else
                {
                    selectedSorting = SORT_BY_TYPE_ASC_FOLDER_FIRST;
                }
            }
            else
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_TYPE_DESC;
                }
                else
                {
                    selectedSorting = SORT_BY_TYPE_ASC;
                }
            }
            break;
        }
        case 3: // size
        {
            if (self.foldersFirst)
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_SIZE_DESC_FOLDER_FIRST;
                }
                else
                {
                    selectedSorting = SORT_BY_SIZE_ASC_FOLDER_FIRST;
                }
            }
            else
            {
                if (self.descending)
                {
                    selectedSorting = SORT_BY_SIZE_DESC;
                }
                else
                {
                    selectedSorting = SORT_BY_SIZE_ASC;
                }
            }
            break;
        }
        default:
            break;
    }
    
	if(self.delegate)
    {
		[self.delegate selectedSortingType:selectedSorting];
    }
    
	if(self.delegate && [self.delegate respondsToSelector:@selector(backFromModalView:)])
    {
		[self.delegate backFromModalView:NO];
    }
	[self.navigationController dismissViewControllerAnimated:YES
                                                  completion:nil];
}

- (void) cancelButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    if(self.delegate && [self.delegate respondsToSelector:@selector(cancelSortingType)])
    {
		[self.delegate cancelSortingType];
    }

	if(self.delegate && [self.delegate respondsToSelector:@selector(backFromModalView:)])
    {
		[self.delegate backFromModalView:NO];
    }
	[self.navigationController dismissViewControllerAnimated:YES
                                                  completion:nil];
}

#pragma mark - TableSelectViewController Delegate

- (void)selectedElementIndex:(NSInteger)elementIndex forTag:(NSInteger)tag
{
    switch (tag)
    {
        case TAG_SORTING_TYPE:
        {
            if (self.sortingOptionPopoverController.popoverVisible)
            {
                [self.sortingOptionPopoverController dismissPopoverAnimated:YES];
                self.sortingOptionPopoverController = nil;
            }
            
            self.selectedSortingOptionIndex = elementIndex;
            [self.tableView reloadData];
            break;
        }
        default:
        {
            break;
        }
    }
}

#pragma mark - UISwitch responders

- (void)switchValueChanged:(id)sender
{
	NSInteger tag = ((UISwitch *)sender).tag;
	switch (tag)
    {
		case TAG_FOLDER_FIRST:
        {
			self.foldersFirst = [sender isOn];
			break;
        }
	}
}

- (void)segmentedValueChanged:(id)sender {
	NSInteger tag = ((UISegmentedControl *)sender).tag;
	switch (tag) {
		case TAG_ASC_DESC:
        {
			switch ([sender selectedSegmentIndex])
            {
				case 0: // Ascending
                {
					self.descending = NO;
					break;
                }
				case 1: // Descending
                {
					self.descending = YES;
					break;
                }
				default:
                {
					break;
                }
			}
            break;
        }
	}
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
