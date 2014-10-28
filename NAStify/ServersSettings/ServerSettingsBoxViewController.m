//
//  ServerSettingsBoxViewController
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "ServerSettingsBoxViewController.h"
#import "BoxAuthorizationNavigationController.h"
#import "AppDelegate.h"
#import "UserAccount.h"
#import "private.h"
#import "SSKeychain.h"

#define TAG_ACCOUNT_NAME 0

@implementation ServerSettingsBoxViewController

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
            self.userAccount.serverType = SERVER_TYPE_DROPBOX;
            self.userAccount.accountName = nil;
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // BoxSDK init
    [BoxSDK sharedSDK].OAuth2Session.clientID = BOX_CLIENT_ID;
    [BoxSDK sharedSDK].OAuth2Session.clientSecret = BOX_CLIENT_SECRET;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(boxAPITokensDidRefresh:)
                                                 name:BoxOAuth2SessionDidBecomeAuthenticatedNotification
                                               object:[BoxSDK sharedSDK].OAuth2Session];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(boxAPITokensDidRefresh:)
                                                 name:BoxOAuth2SessionDidRefreshTokensNotification
                                               object:[BoxSDK sharedSDK].OAuth2Session];
    
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
                    
                    if ([SSKeychain passwordForService:self.userAccount.uuid account:@"token"])
                    {
                        cell.textLabel.text = @"Disconnect account";
                    }
                    else
                    {
                        cell.textLabel.text = @"Connect account";
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
            title = NSLocalizedString(@"Box.net account",nil);
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
                    if ([SSKeychain passwordForService:self.userAccount.uuid account:@"token"] == nil)
                    {
                        // Request connection to Box
                        NSURL *authorizationURL = [BoxSDK sharedSDK].OAuth2Session.authorizeURL;
                        NSString *redirectURI = [BoxSDK sharedSDK].OAuth2Session.redirectURIString;
                        BoxAuthorizationViewController *authorizationViewController = [[BoxAuthorizationViewController alloc] initWithAuthorizationURL:authorizationURL redirectURI:redirectURI];
                        BoxAuthorizationNavigationController *loginNavigation = [[BoxAuthorizationNavigationController alloc] initWithRootViewController:authorizationViewController];
                        authorizationViewController.delegate = loginNavigation;
                        loginNavigation.modalPresentationStyle = UIModalPresentationFormSheet;
                        
                        [self presentViewController:loginNavigation animated:YES completion:nil];
                    }
                    else
                    {
                        // Request Disconnect
                        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Box.net connection",nil)
                                                    message:NSLocalizedString(@"Do you want to disconnect your Box account ?",nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Cancel",nil)
                                          otherButtonTitles:NSLocalizedString(@"Disconnect",nil), nil]
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
    // Delete token from keychain
    [SSKeychain deletePasswordForService:self.userAccount.uuid
                                 account:@"token"];

    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index
{
    if (index != alertView.cancelButtonIndex)
    {
        // Delete token from keychain
        [SSKeychain deletePasswordForService:self.userAccount.uuid
                                     account:@"token"];
        [self.tableView reloadData];
    }
}

#pragma mark - BoxSDK notification handlers

- (void)boxAPITokensDidRefresh:(NSNotification *)notification
{
    NSLog(@"boxAPITokensDidRefresh");
    BoxOAuth2Session *OAuth2Session = (BoxOAuth2Session *) notification.object;
    [self setRefreshTokenInKeychain:OAuth2Session.refreshToken];
}

- (void)setRefreshTokenInKeychain:(NSString *)refreshToken
{
    [SSKeychain setPassword:refreshToken
                 forService:self.userAccount.uuid
                    account:@"token"];
    [self.tableView reloadData];
}

@end

