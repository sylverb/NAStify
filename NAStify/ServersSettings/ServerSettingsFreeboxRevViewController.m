//
//  ServerSettingsFreeboxRevViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServerSettingsFreeboxRevViewController.h"
#import "UserAccount.h"
#import "SSKeychain.h"

typedef enum _SETTINGS_TAG
{
    ADDRESS_TAG = 0,
    PORT_TAG,
    ACCOUNT_NAME_TAG,
    ALERT_IMPORT_TOKEN_TAG,
} SETTINGS_TAG;

@implementation ServerSettingsFreeboxRevViewController

@synthesize textCellProfile, textCellAddress, textCellPort;
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
            self.userAccount.server = @"mafreebox.freebox.fr";
            self.userAccount.port = @"80";
            self.userAccount.serverType = SERVER_TYPE_FREEBOX_REVOLUTION;
            self.userAccount.authenticationType = AUTHENTICATION_TYPE_TOKEN;
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
#if TARGET_OS_IOS
    [self.navigationItem setHidesBackButton:YES];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave 
                                                                                          target:self 
                                                                                          action:@selector(saveButtonAction)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel 
                                                                                           target:self 
                                                                                           action:@selector(cancelButtonAction)];
#endif
    
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
#if TARGET_OS_IOS
    return 3;
#else
    return 4;
#endif
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
            numberOfRows = 2;
            break;
        }
        case 2:
        {
            numberOfRows = 1;
            break;
        }
#if TARGET_OS_TV
        case 3:
        {
            numberOfRows = 1;
            break;
        }
#endif
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
                                         withPlaceHolder:NSLocalizedString(@"Hostname or IP",nil)
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeURL
                                            withDelegate:self
                                                  andTag:ADDRESS_TAG];
                    cell = textCellAddress;
                    break;
                }
                case 1:
                {
                    textCellPort = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCellPort == nil)
                    {
                        textCellPort = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                        reuseIdentifier:TextCellIdentifier];
                    }
                    [textCellPort setCellDataWithLabelString:NSLocalizedString(@"Port:",nil)
                                                withText:userAccount.port
                                         withPlaceHolder:NSLocalizedString(@"Port number",nil)
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypePhonePad
                                            withDelegate:self
                                                  andTag:PORT_TAG];
                    cell = textCellPort;
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
                    if ([SSKeychain passwordForService:self.userAccount.uuid account:@"token"] == nil)
                    {
                        cell = [tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                        if (cell == nil)
                        {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                          reuseIdentifier:CellIdentifier];
                        }
#if TARGET_OS_IOS
                        cell.textLabel.text = NSLocalizedString(@"Save and connect to get token, or tap to import",nil);
#elif TARGET_OS_TV
                        cell.textLabel.text = NSLocalizedString(@"Save and connect to get token",nil);
#endif
                        cell.textLabel.textAlignment = NSTextAlignmentCenter;
                    }
                    else
                    {
                        cell = [tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                        if (cell == nil)
                        {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                          reuseIdentifier:CellIdentifier];
                        }
                        cell.textLabel.text = [SSKeychain passwordForService:self.userAccount.uuid
                                                                     account:@"token"];
                    }
                    break;
                }
            }
            break;
        }
#if TARGET_OS_TV
            case 3:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:CellIdentifier];
                    }
                    cell.textLabel.text = NSLocalizedString(@"Save", nil);
                    cell.textLabel.textAlignment = NSTextAlignmentCenter;
                    break;
                }
            }
            break;
        }
#endif
    }
    
    return cell;
}

#if TARGET_OS_TV
- (BOOL)tableView:(UITableView *)tableView canFocusRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 2)
    {
        return NO;
    }
    else
    {
        return YES;
    }
}
#endif

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (indexPath.section)
    {
#if TARGET_OS_IOS
        case 2:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    if ([SSKeychain passwordForService:self.userAccount.uuid account:@"token"] == nil)
                    {
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Import token",nil)
                                                                        message:NSLocalizedString(@"Enter token coming from another device",nil)
                                                                       delegate:self
                                                              cancelButtonTitle:NSLocalizedString(@"Cancel",nil)
                                                              otherButtonTitles:NSLocalizedString(@"OK",nil), nil];
                        [alert setTag:ALERT_IMPORT_TOKEN_TAG];
                        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
                        
                        [alert show];
                    }
                    else
                    {
                        // Copy token to pasteboard
                        [[UIPasteboard generalPasteboard] setString:[SSKeychain passwordForService:self.userAccount.uuid account:@"token"]];
                        
                        // Show menu to share link(s)
                        NSArray *objectsToShare = [NSArray arrayWithObjects:
                                                   NSLocalizedString(@"Please enter this token in NAStify to access my freebox", nil),
                                                   [SSKeychain passwordForService:self.userAccount.uuid account:@"token"],
                                                   nil];
                        
                        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:objectsToShare
                                                                                                             applicationActivities:nil];
                        
                        NSArray *excludeActivities = [NSArray arrayWithObjects:
                                                      UIActivityTypeAssignToContact,
                                                      UIActivityTypeSaveToCameraRoll,
                                                      UIActivityTypeAddToReadingList,
                                                      UIActivityTypePostToFlickr,
                                                      UIActivityTypePostToVimeo,
                                                      UIActivityTypePostToFacebook,
                                                      UIActivityTypePostToTwitter,
                                                      nil];
                        
                        activityViewController.excludedActivityTypes = excludeActivities;
                        
                        [self presentViewController:activityViewController
                                           animated:YES
                                         completion:nil];

                        // Show information
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Token export",nil)
                                                                        message:NSLocalizedString(@"You can export server's access to another device (if so, don't keep the server using it on this device)",nil)
                                                                       delegate:nil
                                                              cancelButtonTitle:NSLocalizedString(@"Ok",nil)
                                                              otherButtonTitles:nil];
                        [alert show];
                    }
                    break;
                }
                default:
                    break;
            }
            break;
        }
#endif
#if TARGET_OS_TV
        case 3:
        {
            switch (indexPath.row)
            {
                case 0: // Save button
                {
                    [self saveButtonAction];
                    break;
                }
                default:
                    break;
            }
            break;
        }
#endif
        default:
            break;
    }
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
            title = NSLocalizedString(@"Token",nil);
            break;
        }
    }
    return title;
}

#if TARGET_OS_IOS
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == -1)
		return;
    
    switch (alertView.tag) {
        case ALERT_IMPORT_TOKEN_TAG:
        {
            NSString *token = [alertView textFieldAtIndex:0].text;

            [SSKeychain setPassword:token
                         forService:self.userAccount.uuid
                            account:@"token"];
            [self.tableView reloadData];
            break;
        }
    }
}
#endif

#pragma mark - TextField Delegate Methods

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
        [textCellPort.textField becomeFirstResponder];
    }
    else if (textField == textCellPort.textField)
    {
        [textCellProfile.textField becomeFirstResponder];
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
            self.userAccount.server = textField.text;
            break;
        }
        case PORT_TAG:
        {
            self.userAccount.port = textField.text;
            break;
        }
    }
}

- (void)saveButtonAction
{
    [textCellProfile resignFirstResponder];
    [textCellAddress resignFirstResponder];
    [textCellPort resignFirstResponder];
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
                                                                   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:userAccount,@"account",[NSNumber numberWithLong:(long)self.accountIndex],@"accountIndex",nil]];
        
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
                                     account:@"token"];
    }
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end

