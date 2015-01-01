//
//  ServerSettingsMegaViewController
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "ServerSettingsMegaViewController.h"
#import "BoxAuthorizationNavigationController.h"
#import "SBNetworkActivityIndicator.h"
#import "AppDelegate.h"
#import "UserAccount.h"
#import "private.h"
#import "SSKeychain.h"

#define TAG_ACCOUNT_NAME 0
#define TAG_USERNAME     1
#define TAG_PASSWORD     2

@implementation ServerSettingsMegaViewController

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
            self.userAccount.serverType = SERVER_TYPE_MEGA;
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
    
    // Setup SDK
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    self.megaSDK = [[MEGASdk alloc] initWithAppKey:MEGA_KEY
                                         userAgent:[NSString defaultUserAgentString]
                                          basePath:basePath];

    if ([SSKeychain passwordForService:self.userAccount.uuid account:@"token"] != nil)
    {
        self.currentToken = [SSKeychain passwordForService:self.userAccount.uuid account:@"token"];

        [self.megaSDK fastLoginWithSession:self.currentToken
                                  delegate:self];
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
            if (self.currentToken)
            {
                numberOfRows = 1;
            }
            else
            {
                numberOfRows = 3;
            }
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
                case 1:
                {
                    textCellProfile = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCellProfile == nil)
                    {
                        textCellProfile = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                          reuseIdentifier:TextCellIdentifier];
                    }
                    [textCellProfile setCellDataWithLabelString:NSLocalizedString(@"Email:",nil)
                                                       withText:userAccount.userName
                                                withPlaceHolder:NSLocalizedString(@"user's email",nil)
                                                       isSecure:NO
                                               withKeyboardType:UIKeyboardTypeEmailAddress
                                                   withDelegate:self
                                                         andTag:TAG_USERNAME];
                    cell = textCellProfile;
                    break;
                }
                case 2:
                {
                    textCellProfile = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCellProfile == nil)
                    {
                        textCellProfile = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                          reuseIdentifier:TextCellIdentifier];
                    }
                    [textCellProfile setCellDataWithLabelString:NSLocalizedString(@"Password:",nil)
                                                       withText:self.password
                                                withPlaceHolder:NSLocalizedString(@"password",nil)
                                                       isSecure:YES
                                               withKeyboardType:UIKeyboardTypeDefault
                                                   withDelegate:self
                                                         andTag:TAG_PASSWORD];
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
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
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
            title = NSLocalizedString(@"Mega.co.nz account",nil);
            break;
        }
    }
    return title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSString *title = nil;
    switch (section)
    {
        case 1:
        {
            if (self.currentToken)
            {
                title = [NSString stringWithFormat:NSLocalizedString(@"Account: %@",nil),self.userAccount.userName];
            }
            break;
        }
            
        default:
            break;
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
                        [self.megaSDK logoutWithDelegate:self];
                    }
                    else
                    {
                        [self.currentFirstResponder resignFirstResponder];

                        // Send login request
                        NSString *privateKey = [self.megaSDK base64pwkeyForPassword:self.password];
                        NSString *publicKey  = [self.megaSDK hashForBase64pwkey:privateKey email:self.userAccount.userName];
                        
                        [self.megaSDK fastLoginWithEmail:self.userAccount.userName
                                              stringHash:publicKey
                                             base64pwKey:privateKey
                                                delegate:self];
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
        case TAG_USERNAME:
        {
            self.userAccount.userName = textField.text;
            break;
        }
        case TAG_PASSWORD:
        {
            self.password = textField.text;
            break;
        }
    }
    [self.tableView reloadData];
}

- (void)saveButtonAction
{
    [self.currentFirstResponder resignFirstResponder];
    
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
                                                        message:NSLocalizedString(@"You have to connect to Mega first", nil)
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

#pragma mark - MEGARequestDelegate

- (void)onRequestStart:(MEGASdk *)api request:(MEGARequest *)request
{
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
}

- (void)onRequestFinish:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error
{
    // End the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] endActivity:self];

    switch (request.type)
    {
        case MEGARequestTypeLogin:
        {
            if (error.type == MEGAErrorTypeApiOk)
            {
                self.currentToken = self.megaSDK.dumpSession;
            }
            else
            {
                NSString *errorString = nil;
                switch (error.type)
                {
                    case MEGAErrorTypeApiEArgs:
                    case MEGAErrorTypeApiENoent:
                    {
                        errorString = NSLocalizedString(@"Email or password invalid.",nil);
                        break;
                    }
                    default:
                    {
                        errorString = NSLocalizedString(error.name,nil);
                        NSLog(@"error %ld",error.type);
                        break;
                    }
                }
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil)
                                                                message:errorString
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"ok", @"OK")
                                                      otherButtonTitles:nil];
                [alert show];
            }
            
            break;
        }
        case MEGARequestTypeLogout:
        {
            if (error.type == MEGAErrorTypeApiOk)
            {
                self.currentToken = nil;
                [SSKeychain deletePasswordForService:self.userAccount.uuid
                                             account:@"token"];
            }
            else
            {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil)
                                                                message:NSLocalizedString(error.name,nil)
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"ok", @"OK")
                                                      otherButtonTitles:nil];
                [alert show];
            }
            break;
        }
        default:
        {
            NSLog(@"request %ld ignored",request.type);
            break;
        }
    }
    
    [self.tableView reloadData];
}

- (void)onRequestTemporaryError:(MEGASdk *)api request:(MEGARequest *)request error:(MEGAError *)error
{
    NSLog(@"onRequestTemporaryError %@",error);
}

@end

