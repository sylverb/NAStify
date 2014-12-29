//
//  ServerSettingsOneDriveViewController
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "ServerSettingsOneDriveViewController.h"
#import "BoxAuthorizationNavigationController.h"
#import "SBNetworkActivityIndicator.h"
#import "AppDelegate.h"
#import "UserAccount.h"
#import "private.h"
#import "SSKeychain.h"

#define TAG_ACCOUNT_NAME 0

@implementation ServerSettingsOneDriveViewController

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
    
    // Get login status id token is present
    self.liveClient = [[LiveConnectClient alloc] initManuallyWithClientId:ONEDRIVE_CLIENT_ID
                                                                   scopes:[NSArray arrayWithObjects:
                                                                           @"wl.signin",
                                                                           @"wl.skydrive_update",
                                                                           @"wl.offline_access", nil]
                                                                 delegate:self];
    
    if (self.accountIndex == -1)
    {
        // If we are creating a new account, we have to clear OneCloud cookies
        // elseway the OneCloud login window will use exiting account instead
        // of asking for email/password
        [self.liveClient logout];
    }
    else if ([SSKeychain passwordForService:self.userAccount.uuid account:@"token"] != nil)
    {
        self.currentToken = [SSKeychain passwordForService:self.userAccount.uuid account:@"token"];
        // Start the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];

        [self.liveClient refreshSessionWithDelegate:self
                                       refreshToken:self.currentToken
                                          userState:@"status"];
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
                    
                    if (self.currentToken == nil)
                    {
                        cell.textLabel.text = NSLocalizedString(@"Connect account",nil);
                    }
                    else
                    {
                        cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Disconnect",nil)];
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
            title = NSLocalizedString(@"Microsoft OneDrive account",nil);
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
                    if (self.currentToken)
                    {
                        // Sign out
                        [self.liveClient logoutWithDelegate:self
                                                  userState:@"logout"];
                    }
                    else
                    {
                        // Show login window
                        [self.liveClient login:self
                                        scopes:[NSArray arrayWithObjects:
                                                @"wl.signin",
                                                @"wl.skydrive_update",
                                                @"wl.offline_access", nil]
                                      delegate:self
                                     userState:@"login"];
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
    
    if (self.currentToken)
    {
        [SSKeychain setPassword:self.currentToken
                     forService:self.userAccount.uuid
                        account:@"token"];
        
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
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                        message:NSLocalizedString(@"You have to connect to Microsoft OneDrive first", nil)
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (void)cancelButtonAction
{
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark - LiveAuthDelegate

- (void)authCompleted:(LiveConnectSessionStatus) status
              session:(LiveConnectSession *) session
            userState:(id) userState
{
    if ([userState isEqual:@"status"])
    {
        // End the network activity spinner
        [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

        switch (status)
        {
            case LiveAuthConnected:
            {
                // token is valid
                break;
            }
            default:
            {
                // token is not valid
                self.currentToken = nil;
                break;
            }
        }
    }
    if ([userState isEqual:@"login"])
    {
        if (session != nil)
        {
            self.currentToken = session.refreshToken;
            NSLog(@"Signed in.");
        }
    }
    if ([userState isEqual:@"logout"])
    {
        [SSKeychain deletePasswordForService:self.userAccount.uuid
                                     account:@"token"];
        self.currentToken = nil;
    }
    
    [self.tableView reloadData];
}

- (void)authFailed:(NSError *) error
         userState:(id)userState
{
    NSLog(@"Error: %@", [error localizedDescription]);
}

@end

