//
//  ShareViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "ShareViewController.h"
#import "TextCell.h"
#import "AltTextCell.h"

#define PASSWORD_SECTION_INDEX 0
#define VALIDITY_SECTION_INDEX 1

#define PASSWORD_TAG    1
#define VALIDITY_TAG    2

@implementation ShareViewController

#pragma mark - Initialization

- (id)init
{
	if ((self = [super init]))
    {
		self.files = nil;
        self.password = nil;
        self.duration = 0;
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
    UIBarButtonItem *shareButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Share",nil)
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(shareButton:event:)];
	UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                      target:self
                                                                                      action:@selector(cancelButton:event:)];
    
    NSMutableArray *buttons = [NSMutableArray arrayWithCapacity:5];
    
    [buttons addObject:flexibleSpaceButtonItem];
    [buttons addObject:shareButtonItem];
	[buttons addObject:flexibleSpaceButtonItem];
	[buttons addObject:cancelButtonItem];
	[buttons addObject:flexibleSpaceButtonItem];
	[self setToolbarItems:buttons];
    
    if ([self.files count] > 1)
    {
        self.navigationItem.title = @"Share";
    }
    else
    {
        FileItem *file = [self.files firstObject];
        self.navigationItem.title = [NSString stringWithFormat:@"Share %@", file.name];
    }
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [self.navigationController.toolbar setTintColor:[UIColor blackColor]];
    
    switch ([self.connectionManager shareValidityUnit])
    {
        case SHARING_VALIDITY_UNIT_DAY:
        {
            NSDate *today = [[NSDate alloc] init];
            NSCalendar *gregorian = [[NSCalendar alloc]
                                     initWithCalendarIdentifier:NSGregorianCalendar];
            NSUInteger units = NSSecondCalendarUnit;
            NSDateComponents *offsetComponents = [[NSDateComponents alloc] init];
            
            self.shareValidityOptions = [NSArray arrayWithObjects:
                                         NSLocalizedString(@"Forever", nil),
                                         NSLocalizedString(@"1 day", nil),
                                         NSLocalizedString(@"2 days", nil),
                                         NSLocalizedString(@"3 days", nil),
                                         NSLocalizedString(@"4 days", nil),
                                         NSLocalizedString(@"5 days", nil),
                                         NSLocalizedString(@"6 days", nil),
                                         NSLocalizedString(@"1 week", nil),
                                         NSLocalizedString(@"2 weeks", nil),
                                         NSLocalizedString(@"3 weeks", nil),
                                         NSLocalizedString(@"1 month", nil),
                                         NSLocalizedString(@"2 months", nil),
                                         NSLocalizedString(@"3 months", nil),
                                         NSLocalizedString(@"4 months", nil),
                                         NSLocalizedString(@"5 months", nil),
                                         NSLocalizedString(@"6 months", nil),
                                         NSLocalizedString(@"7 months", nil),
                                         NSLocalizedString(@"8 months", nil),
                                         NSLocalizedString(@"9 months", nil),
                                         NSLocalizedString(@"10 months", nil),
                                         NSLocalizedString(@"11 months", nil),
                                         NSLocalizedString(@"1 year", nil),
                                         nil];
            
            self.shareValidityValues = [NSMutableArray arrayWithObject:
                                        [NSNumber numberWithInteger:0]];
            
            [offsetComponents setDay:1]; // 1 day
            
            NSDate *endDate = [gregorian dateByAddingComponents:offsetComponents
                                                         toDate:today
                                                        options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:2]; // 2 days
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:3]; // 3 days
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:4]; // 4 days
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:5]; // 5 days
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:6]; // 6 days
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:7]; // 1 week
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:14]; // 2 weeks
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:21]; // 3 weeks
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:0];
            [offsetComponents setMonth:1]; // 1 month
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:2]; // 2 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:3]; // 3 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:4]; // 4 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:5]; // 5 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:6]; // 6 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:7]; // 7 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:8]; // 8 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:9]; // 9 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:10]; // 10 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:11]; // 11 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:0];
            [offsetComponents setYear:1]; // 1 year
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            break;
        }
        case SHARING_VALIDITY_UNIT_HOUR:
        {
            NSDate *today = [[NSDate alloc] init];
            NSCalendar *gregorian = [[NSCalendar alloc]
                                     initWithCalendarIdentifier:NSGregorianCalendar];
            NSUInteger units = NSSecondCalendarUnit;
            NSDateComponents *offsetComponents = [[NSDateComponents alloc] init];
            
            self.shareValidityOptions = [NSArray arrayWithObjects:
                                         NSLocalizedString(@"Forever", nil),
                                         NSLocalizedString(@"1 hour", nil),
                                         NSLocalizedString(@"2 hours", nil),
                                         NSLocalizedString(@"3 hours", nil),
                                         NSLocalizedString(@"4 hours", nil),
                                         NSLocalizedString(@"6 hours", nil),
                                         NSLocalizedString(@"8 hours", nil),
                                         NSLocalizedString(@"12 hours", nil),
                                         NSLocalizedString(@"18 hours", nil),
                                         NSLocalizedString(@"1 day", nil),
                                         NSLocalizedString(@"2 days", nil),
                                         NSLocalizedString(@"3 days", nil),
                                         NSLocalizedString(@"4 days", nil),
                                         NSLocalizedString(@"5 days", nil),
                                         NSLocalizedString(@"6 days", nil),
                                         NSLocalizedString(@"1 week", nil),
                                         NSLocalizedString(@"2 weeks", nil),
                                         NSLocalizedString(@"3 weeks", nil),
                                         NSLocalizedString(@"1 month", nil),
                                         NSLocalizedString(@"2 months", nil),
                                         NSLocalizedString(@"3 months", nil),
                                         NSLocalizedString(@"4 months", nil),
                                         NSLocalizedString(@"5 months", nil),
                                         NSLocalizedString(@"6 months", nil),
                                         NSLocalizedString(@"7 months", nil),
                                         NSLocalizedString(@"8 months", nil),
                                         NSLocalizedString(@"9 months", nil),
                                         NSLocalizedString(@"10 months", nil),
                                         NSLocalizedString(@"11 months", nil),
                                         NSLocalizedString(@"1 year", nil),
                                         nil];
            
            self.shareValidityValues = [NSMutableArray arrayWithObject:
                                        [NSNumber numberWithInteger:0]];

            [offsetComponents setHour:1]; // 1 hour
            
            NSDate *endDate = [gregorian dateByAddingComponents:offsetComponents
                                                         toDate:today
                                                        options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setHour:2]; // 2 hours
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setHour:3]; // 3 hours
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setHour:4]; // 4 hours
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setHour:6]; // 6 hours
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setHour:8]; // 8 hours
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setHour:12]; // 12 hours
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setHour:18]; // 18 hours
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setHour:0];
            [offsetComponents setDay:1]; // 1 day
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:2]; // 2 days
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:3]; // 3 days
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:4]; // 4 days
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:5]; // 5 days
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:6]; // 6 days
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:7]; // 1 week
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:14]; // 2 weeks
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:21]; // 3 weeks
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setDay:0];
            [offsetComponents setMonth:1]; // 1 month
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:2]; // 2 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:3]; // 3 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:4]; // 4 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:5]; // 5 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:6]; // 6 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:7]; // 7 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:8]; // 8 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:9]; // 9 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:10]; // 10 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:11]; // 11 months
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            
            [offsetComponents setMonth:0];
            [offsetComponents setYear:1]; // 1 year
            
            endDate = [gregorian dateByAddingComponents:offsetComponents
                                                 toDate:today
                                                options:0];
            
            [self.shareValidityValues addObject:[NSNumber numberWithInteger:[gregorian components:units
                                                                                         fromDate:today
                                                                                           toDate:endDate
                                                                                          options:0].second]];
            break;
        }
        case SHARING_VALIDITY_UNIT_NOT_SUPPORTED:
        default:
        {
            break;
        }
    }
    
    self.shareValidityIndex = 0;

}

- (void)viewWillAppear:(BOOL)animated
{
	[self.navigationController setToolbarHidden:NO animated:NO];
	
    [super viewWillAppear:animated];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    NSInteger rows = 0;
    switch (section)
    {
        case PASSWORD_SECTION_INDEX:
        {
            if (ServerSupportsSharingFeature(Password))
            {
                rows = 1;
            }
            break;
        }
        case VALIDITY_SECTION_INDEX:
        {
            if (ServerSupportsSharingFeature(ValidityPeriod))
            {
                rows = 1;
            }
            break;
        }
        default:
        {
            break;
        }
    }
    return rows;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *AltTextCellIdentifier = @"AltTextCell";
	static NSString *TextCellIdentifier = @"TextCell";
	
	UITableViewCell *cell = nil;
	switch (indexPath.section)
    {
		case PASSWORD_SECTION_INDEX:
		{
			switch (indexPath.row)
            {
                case 0:
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
                case 1:
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
			}
			break;
		}
        case VALIDITY_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    TextCell *textCell = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCell == nil)
                    {
                        textCell = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:TextCellIdentifier];
                    }
                    [textCell setCellDataWithLabelString:NSLocalizedString(@"Validity period", nil)
                                                withText:[self.shareValidityOptions objectAtIndex:self.shareValidityIndex]
                                         withPlaceHolder:nil
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeDefault
                                            withDelegate:nil
                                                  andTag:-1];
                    textCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    textCell.textField.enabled = NO;
                    cell = textCell;
                    break;
                }
            }
            break;
        }
    }
    
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (indexPath.section)
    {
        case VALIDITY_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
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
                    tableSelectViewController.elements = self.shareValidityOptions;
                    tableSelectViewController.selectedElement = self.shareValidityIndex;
                    tableSelectViewController.delegate = self;
                    tableSelectViewController.tag = VALIDITY_TAG;
                    
                    [self presentViewController:tableSelectViewController animated:YES completion:nil];
                    break;
                }
            }
            break;
        }
        default:
        {
            break;
        }
    }
}

#pragma mark - Tabbar buttons Methods

- (void)shareButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    if (self.delegate)
    {
        [self.delegate shareFiles:self.files
                         duration:self.duration
                         password:self.password];
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

- (void)selectedElementIndex:(NSInteger)elementIndex forTag:(NSInteger)tag
{
	switch (tag)
    {
        case VALIDITY_TAG:
        {
            self.shareValidityIndex = elementIndex;
            self.duration = [[self.shareValidityValues objectAtIndex:elementIndex] floatValue];
            break;
        }
    }
    [self.tableView reloadData];
}

#pragma mark - Rotating views

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// Return YES for supported orientations
	return YES;
}

@end
