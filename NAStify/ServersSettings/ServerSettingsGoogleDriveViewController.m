//
//  ServerSettingsGoogleDriveViewController
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "ServerSettingsGoogleDriveViewController.h"
#import "BoxAuthorizationNavigationController.h"
#import "GTLDrive.h"
#import "GTLDriveConstants.h"
#import "AppDelegate.h"
#import "UserAccount.h"
#import "private.h"
#import "SSKeychain.h"

#define TAG_ACCOUNT_NAME 0

@implementation ServerSettingsGoogleDriveViewController

@synthesize textCellProfile;
@synthesize userAccount, accountIndex;

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index
{
    if ((self = [super initWithStyle:style]))
    {
        self.userAccount = account;
        self.accountIndex = index;
        
        // If it's a new account, create a new one
        if (self.accountIndex == -1)
        {
            self.userAccount = [[UserAccount alloc] init];
            self.userAccount.serverType = SERVER_TYPE_GOOGLEDRIVE;
            self.userAccount.accountName = nil;
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Buttons setup
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
    
    // Check for authorization.
    GTMOAuth2Authentication *auth =
    [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:self.userAccount.uuid
                                                          clientID:GOOGLEDRIVE_CLIENT_ID
                                                      clientSecret:GOOGLEDRIVE_CLIENT_SECRET];
    if ([auth canAuthorize])
    {
        self.isAuthorized = YES;
        self.currentAuth = auth;
    }
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
                    
                    if (self.isAuthorized)
                    {
                        cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Disconnect %@",nil),self.currentAuth.userEmail];
                    }
                    else
                    {
                        cell.textLabel.text = NSLocalizedString(@"Connect account",nil);
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
            title = NSLocalizedString(@"GoogleDrive account",nil);
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
                    if (self.isAuthorized)
                    {
                        // Sign out
                        [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:self.userAccount.uuid];
                        self.isAuthorized = NO;
                        self.currentAuth = nil;
                        [self.tableView reloadData];
                    }
                    else
                    {
                        // Show goggle login window.
                        GTMOAuth2ViewControllerTouch *viewController =
                        [[GTMOAuth2ViewControllerTouch alloc] initWithScope:kGTLAuthScopeDrive
                                                                   clientID:GOOGLEDRIVE_CLIENT_ID
                                                               clientSecret:GOOGLEDRIVE_CLIENT_SECRET
                                                           keychainItemName:self.userAccount.uuid
                                                                   delegate:self
                                                           finishedSelector:@selector(viewController:finishedWithAuth:error:)];
                        
                        [[self navigationController] pushViewController:viewController
                                                               animated:YES];
                    }
                    break;
                }
            }
        }
    }
}

- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController finishedWithAuth:(GTMOAuth2Authentication *)auth error:(NSError *)error
{
    [viewController dismissViewControllerAnimated:YES completion:nil];
    if (error == nil)
    {
        self.isAuthorized = YES;
        self.currentAuth = auth;
        
        [self.tableView reloadData];
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

- (void)cancelButtonAction
{
    if (self.accountIndex == -1)
    {
        // Delete account from keychain
        [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:self.userAccount.uuid];
    }
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end

