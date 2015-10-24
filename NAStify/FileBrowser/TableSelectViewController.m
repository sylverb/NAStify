//
//  TableSelectViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "TableSelectViewController.h"


@implementation TableSelectViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super init];
    if (self)
    {
        self.elements = nil;
        self.selectedElement = -1;
        self.tag = -1;
        self.style = style;
    }
    return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.edgesForExtendedLayout = UIRectEdgeNone;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:self.style];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                      UIViewAutoresizingFlexibleHeight |
                                      UIViewAutoresizingFlexibleBottomMargin;
    
    [self.view addSubview:self.tableView];
}

- (void)viewWillAppear:(BOOL)animated
{
    NSIndexPath *scrollIndexPath = [NSIndexPath indexPathForRow:self.selectedElement inSection:0];
    [[self tableView] reloadData];
    [[self tableView] scrollToRowAtIndexPath:scrollIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    [super viewWillAppear:animated];
}

#if TARGET_OS_TV
- (UIView *)preferredFocusedView
{
    NSIndexPath *scrollIndexPath = [NSIndexPath indexPathForRow:self.selectedElement inSection:0];
    return [self.tableView cellForRowAtIndexPath:scrollIndexPath];
}
#endif

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.elements count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
	
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (self.selectedElement == indexPath.row)
    {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
	else
    {
		cell.accessoryType = UITableViewCellAccessoryNone;
    }

    NSString *elementName = [self.elements objectAtIndex:indexPath.row];
    cell.textLabel.text = elementName;
	
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (self.delegate != nil)
    {
		[self.delegate selectedElementIndex:indexPath.row forTag:self.tag];
	}
    
    // Update checkmark position
    [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:self.selectedElement inSection:0]].accessoryType = UITableViewCellAccessoryNone;
    [tableView cellForRowAtIndexPath:indexPath].accessoryType = UITableViewCellAccessoryCheckmark;
    self.selectedElement = indexPath.row;
    
    // Dismiss the view
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
