//
//  ServerSettingsDropboxViewController
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServerSettingsDropboxViewController.h"
#import "AppDelegate.h"
#import "UserAccount.h"

#define TAG_ACCOUNT_NAME 0

@implementation ServerSettingsDropboxViewController

@synthesize textCellProfile;
@synthesize userAccount, accountIndex;

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index
{
    if ((self = [super initWithStyle:style])) {
        self.userAccount = account;
        self.accountIndex = index;
        
        // If it's a new account, create a new one
        if (self.accountIndex == -1) {
            self.userAccount = [[UserAccount alloc] init];
            self.userAccount.serverType = SERVER_TYPE_DROPBOX;
            self.userAccount.accountName = nil;
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationItem setHidesBackButton:YES];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave 
                                                                                          target:self 
                                                                                          action:@selector(saveButtonAction)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel 
                                                                                           target:self 
                                                                                           action:@selector(cancelButtonAction)];
    
    // Load custom tableView
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;

    self.navigationItem.title = NSLocalizedString(@"Settings",nil);
}

- (void)viewWillDisappear:(BOOL)animated
{
    if ([self.currentFirstResponder canResignFirstResponder])
    {
        [self.currentFirstResponder resignFirstResponder];
    }
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows = 0;

    switch (section)
    {
        case 0:
        {
            numberOfRows = 1;
            break;
        }
        case 1:
        {
            numberOfRows = 1;
            break;
        }
    }
    return numberOfRows;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *TextCellIdentifier = @"TextCell";
    static NSString *CellIdentifier = @"Cell";

    UITableViewCell *cell = nil;

    switch (indexPath.section)
    {
        case 0:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    textCellProfile = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCellProfile == nil)
                    {
                        textCellProfile = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                           reuseIdentifier:TextCellIdentifier];
                    }
                    [textCellProfile setCellDataWithLabelString:NSLocalizedString(@"Profile Name:",nil)
                                                withText:userAccount.accountName
                                         withPlaceHolder:NSLocalizedString(@"Description",nil)
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeDefault
                                            withDelegate:self
                                                  andTag:TAG_ACCOUNT_NAME];
                    cell = textCellProfile;
                    break;
                }
            }
            break;
        }
        case 1:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                          reuseIdentifier:CellIdentifier];
                    }
                    cell.textLabel.textAlignment = NSTextAlignmentCenter;
                    
                    if (self.userAccount.userName)
                    {
                        cell.textLabel.text = @"Unlink account";
                    }
                    else
                    {
                        cell.textLabel.text = @"Link account";
                    }
                    break;
                }
            }
            break;
        }
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString * title = nil;
    switch (section)
    {
        case 0:
        {
            break;
        }
        case 1:
        {
            title = NSLocalizedString(@"Account",nil);
            break;
        }
    }
    return title;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section)
    {
        case 1:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    if (self.userAccount.userName == nil)
                    {
                        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxLink:) name:@"DROPBOXLINK" object:nil];
                        
                        // Request link to Dropbox
                        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                        
                        [[DBSession sharedSession] linkFromController:appDelegate.window.rootViewController];
                    }
                    else
                    {
                        // Request unlink
                        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Dropbox link",nil)
                                                    message:NSLocalizedString(@"Do you want to unlink your dropbox account ?",nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel",nil)
                                          otherButtonTitles:NSLocalizedString(@"Unlink",nil), nil]
                         show];
                    }
                    break;
                }
            }
        }
    }
}

#pragma mark - TextField Delegate Methods

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.currentFirstResponder = textField;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    self.currentFirstResponder = nil;
    [textField resignFirstResponder];
    switch (textField.tag)
    {
        case TAG_ACCOUNT_NAME:
        {
            self.userAccount.accountName = textField.text;
            break;
        }
    }
}

- (void)saveButtonAction
{
    [textCellProfile resignFirstResponder];
    
    if (self.userAccount.userName)
    {
        
        if (self.accountIndex == -1)
        {
            NSNotification* notification = [NSNotification notificationWithName:@"ADDACCOUNT"
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:userAccount,@"account",nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        else
        {
            NSNotification* notification = [NSNotification notificationWithName:@"UPDATEACCOUNT"
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:userAccount,@"account",[NSNumber numberWithInteger:self.accountIndex],@"accountIndex",nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
    else
    {
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

- (void)cancelButtonAction
{
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark - Notification Methods

- (void)dropboxLink:(NSNotification*)notification
{
    if ([[notification userInfo] objectForKey:@"userId"])
    {
        NSString *userId = [[notification userInfo] objectForKey:@"userId"];
        
        // Check that no existing account is linked for this userId
        BOOL existingAccount = NO;
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
        NSData * accountsData = [defaults objectForKey:@"accounts"];
        NSArray *accounts = nil;
        if (!accountsData)
        {
            accounts = [[NSMutableArray alloc] init];
        }
        else
        {
            accounts = [[NSMutableArray alloc] initWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:accountsData]];
        }

        for (UserAccount *account in accounts)
        {
            if ((account.serverType == SERVER_TYPE_DROPBOX) &&
                ([account.userName isEqualToString:userId]))
            {
                existingAccount = YES;
            }
        }
        
        if (existingAccount)
        {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Dropbox link",nil)
                                        message:NSLocalizedString(@"A server is already configured for this Dropbox account",nil)
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"Ok",nil)
                              otherButtonTitles:nil]
             show];
        }
        else
        {
            self.userAccount.userName = [[notification userInfo] objectForKey:@"userId"];
        }
    }
    else
    {
        // Link cancelled
        self.userAccount.userName = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"DROPBOXLINK"
                                                  object:nil];
    [self.tableView reloadData];
}

#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index
{
    if (index != alertView.cancelButtonIndex)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dropboxLink:) name:@"DROPBOXLINK" object:nil];

        [[DBSession sharedSession] unlinkUserId:self.userAccount.userName];
        
        self.userAccount.userName = nil;
        [self.tableView reloadData];
    }
}


@end

