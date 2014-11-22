//
//  ServerSettingsSambaViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServerSettingsSambaViewController.h"
#import "AppDelegate.h"
#import "UserAccount.h"
#import "SSKeychain.h"

typedef enum _SETTINGS_TAG
{
    ADDRESS_TAG = 0,
    UNAME_TAG,
    PWD_TAG,
    ACCOUNT_NAME_TAG,
} SETTINGS_TAG;

@implementation ServerSettingsSambaViewController

@synthesize textCellProfile, textCellAddress, textCellUsername, textCellPassword;
@synthesize userAccount, accountIndex;

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index
{
    if ((self = [super initWithStyle:style])) {
        self.userAccount = account;
        self.accountIndex = index;
        
        // If it's a new account, create a new one
        if (self.accountIndex == -1) {
            self.userAccount = [[UserAccount alloc] init];
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
    
    // Init localPassword with keychain content
    self.localPassword = [SSKeychain passwordForService:self.userAccount.uuid account:@"password"];
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
    return 3;
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
        case 2:
        {
            numberOfRows = 2;
            break;
        }
    }
    return numberOfRows;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *TextCellIdentifier = @"TextCell";
    
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
                    [textCellProfile setCellDataWithLabelString:NSLocalizedString(@"Profile Name:",@"")
                                                       withText:userAccount.accountName
                                                withPlaceHolder:NSLocalizedString(@"Description",@"")
                                                       isSecure:NO
                                               withKeyboardType:UIKeyboardTypeDefault
                                                   withDelegate:self
                                                         andTag:ACCOUNT_NAME_TAG];
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
                    textCellAddress = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCellAddress == nil)
                    {
                        textCellAddress = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                          reuseIdentifier:TextCellIdentifier];
                    }
                    [textCellAddress setCellDataWithLabelString:NSLocalizedString(@"Address:",nil)
                                                       withText:userAccount.server
                                                withPlaceHolder:NSLocalizedString(@"Hostname/IP",nil)
                                                       isSecure:NO
                                               withKeyboardType:UIKeyboardTypeURL
                                                   withDelegate:self
                                                         andTag:ADDRESS_TAG];
                    cell = textCellAddress;
                    break;
                }
            }
            break;
        }
        case 2:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    textCellUsername = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCellUsername == nil)
                    {
                        textCellUsername = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                           reuseIdentifier:TextCellIdentifier];
                    }
                    [textCellUsername setCellDataWithLabelString:NSLocalizedString(@"Username:",@"")
                                                        withText:userAccount.userName
                                                 withPlaceHolder:NSLocalizedString(@"Username",@"")
                                                        isSecure:NO
                                                withKeyboardType:UIKeyboardTypeDefault
                                                    withDelegate:self
                                                          andTag:UNAME_TAG];
                    cell = textCellUsername;
                    break;
                }
                case 1:
                {
                    textCellPassword = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCellPassword == nil)
                    {
                        textCellPassword = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                           reuseIdentifier:TextCellIdentifier];
                    }
                    [textCellPassword setCellDataWithLabelString:NSLocalizedString(@"Password:",@"")
                                                        withText:self.localPassword
                                                 withPlaceHolder:NSLocalizedString(@"Password",@"")
                                                        isSecure:YES
                                                withKeyboardType:UIKeyboardTypeDefault
                                                    withDelegate:self
                                                          andTag:PWD_TAG];
                    cell = textCellPassword;
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
            title = NSLocalizedString(@"Server Connection",nil);
            break;
        }
        case 2:
        {
            title = NSLocalizedString(@"Security",nil);
            break;
        }
    }
    return title;
}

#pragma mark -
#pragma mark TextField Delegate Methods
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.currentFirstResponder = textField;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    if (textField == textCellProfile.textField)
    {
        [textCellAddress.textField becomeFirstResponder];
    }
    else if (textField == textCellAddress.textField)
    {
        [textCellUsername.textField becomeFirstResponder];
    }
    else if (textField == textCellUsername.textField)
    {
        [textCellPassword.textField becomeFirstResponder];
    }
    else if (textField == textCellPassword.textField)
    {
        [textCellAddress.textField becomeFirstResponder];
    }
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    self.currentFirstResponder = nil;
    [textField resignFirstResponder];
    switch (textField.tag)
    {
        case ACCOUNT_NAME_TAG:
        {
            self.userAccount.accountName = textField.text;
            break;
        }
        case ADDRESS_TAG:
        {
            if ([textField.text hasPrefix:@"https://"])
            {
                self.userAccount.boolSSL = YES;
            }
            else
            {
                self.userAccount.boolSSL = NO;
            }
            self.userAccount.server = textField.text;
            break;
        }
        case UNAME_TAG:
        {
            self.userAccount.userName = textField.text;
            break;
        }
        case PWD_TAG:
        {
            self.localPassword = textField.text;
            break;
        }
    }
}

- (void)saveButtonAction {
    [textCellProfile resignFirstResponder];
    [textCellAddress resignFirstResponder];
    [textCellUsername resignFirstResponder];
    [textCellPassword resignFirstResponder];
    
    [SSKeychain setPassword:self.localPassword
                 forService:self.userAccount.uuid
                    account:@"password"];
    
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
                                                                   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:userAccount,@"account",[NSNumber numberWithLong:self.accountIndex],@"accountIndex",nil]];
        
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
    }
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)cancelButtonAction
{
    if (self.accountIndex == -1)
    {
        // Remove entries in keychain
        [SSKeychain deletePasswordForService:self.userAccount.uuid
                                     account:@"password"];
    }
    [self.navigationController popToRootViewControllerAnimated:YES];
}


@end

