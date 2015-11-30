//
//  ServerSettingsSambaViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServerSettingsSambaViewController.h"
#import "UserAccount.h"
#import "SSKeychain.h"

typedef enum _SETTINGS_TAG
{
    ADDRESS_TAG = 0,
    PATH_TAG,
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
        self.localSettings = [NSMutableDictionary dictionaryWithDictionary:self.userAccount.settings];
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
    
#if TARGET_OS_TV
    self.tableView.layoutMargins = UIEdgeInsetsMake(0, 90, 0, 90);
    self.invisibleTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.invisibleTextField.delegate = self;
    [self.view addSubview:self.invisibleTextField];
#endif
    
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
#if TARGET_OS_IOS
    return 3;
#elif TARGET_OS_TV
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
            numberOfRows = 2;
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
#if TARGET_OS_IOS
    static NSString *TextCellIdentifier = @"TextCell";
#elif TARGET_OS_TV
    static NSString *CellIdentifier1 = @"Cell1";
    static NSString *TableCellIdentifier = @"TableCell";
#endif
    
    UITableViewCell *cell = nil;
    
    switch (indexPath.section)
    {
        case 0:
        {
            switch (indexPath.row)
            {
                case 0:
                {
#if TARGET_OS_IOS
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
#elif TARGET_OS_TV
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Profile Name",nil);
                    cell.detailTextLabel.text = userAccount.accountName;
#endif
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
#if TARGET_OS_IOS
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
#elif TARGET_OS_TV
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Address",nil);
                    cell.detailTextLabel.text = userAccount.server;
#endif
                    break;
                }
                case 1:
                {
#if TARGET_OS_IOS
                    self.textCellPath = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (self.textCellPath == nil)
                    {
                        self.textCellPath = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                            reuseIdentifier:TextCellIdentifier];
                    }
                    [self.textCellPath setCellDataWithLabelString:NSLocalizedString(@"Start path:",nil)
                                                         withText:[self.localSettings objectForKey:@"path"]
                                                  withPlaceHolder:NSLocalizedString(@"Start path",nil)
                                                         isSecure:NO
                                                 withKeyboardType:UIKeyboardTypeDefault
                                                     withDelegate:self
                                                           andTag:PATH_TAG];
                    cell = self.textCellPath;
#elif TARGET_OS_TV
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Start path (optional)",nil);
                    cell.detailTextLabel.text = [self.localSettings objectForKey:@"path"];
#endif
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
#if TARGET_OS_IOS
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
#elif TARGET_OS_TV
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Username",nil);
                    cell.detailTextLabel.text = userAccount.userName;
#endif
                    break;
                }
                case 1:
                {
#if TARGET_OS_IOS
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
#elif TARGET_OS_TV
                    NSMutableString *dottedPassword = [NSMutableString new];
                    
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Password",nil);
                    
                    for (int i = 0; i < [self.localPassword length]; i++)
                    {
                        [dottedPassword appendString:@"●"];
                    }
                    cell.detailTextLabel.text = dottedPassword;
#endif
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
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:TableCellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:TableCellIdentifier];
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
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section)
    {
        case 0:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    self.invisibleTextField.text = userAccount.accountName;
                    self.invisibleTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter account name"];
                    self.invisibleTextField.keyboardType = UIKeyboardTypeDefault;
                    self.invisibleTextField.secureTextEntry = NO;
                    self.invisibleTextField.tag = ACCOUNT_NAME_TAG;
                    [self.invisibleTextField becomeFirstResponder];
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case 1:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    self.invisibleTextField.text = userAccount.server;
                    self.invisibleTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter server IP or hostname"];
                    self.invisibleTextField.keyboardType = UIKeyboardTypeURL;
                    self.invisibleTextField.secureTextEntry = NO;
                    self.invisibleTextField.tag = ADDRESS_TAG;
                    [self.invisibleTextField becomeFirstResponder];
                    break;
                }
                case 1:
                {
                    self.invisibleTextField.text = [self.localSettings objectForKey:@"path"];
                    self.invisibleTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter start path"];
                    self.invisibleTextField.keyboardType = UIKeyboardTypeDefault;
                    self.invisibleTextField.secureTextEntry = NO;
                    self.invisibleTextField.tag = PATH_TAG;
                    [self.invisibleTextField becomeFirstResponder];
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
                    self.invisibleTextField.text = userAccount.userName;
                    self.invisibleTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter username"];
                    self.invisibleTextField.keyboardType = UIKeyboardTypeDefault;
                    self.invisibleTextField.secureTextEntry = NO;
                    self.invisibleTextField.tag = UNAME_TAG;
                    [self.invisibleTextField becomeFirstResponder];
                    break;
                }
                case 1:
                {
                    self.invisibleTextField.text = self.localPassword;
                    self.invisibleTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter password"];
                    self.invisibleTextField.keyboardType = UIKeyboardTypeDefault;
                    self.invisibleTextField.secureTextEntry = YES;
                    self.invisibleTextField.tag = PWD_TAG;
                    [self.invisibleTextField becomeFirstResponder];
                    break;
                }
                default:
                    break;
            }
            break;
        }
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
            
        default:
            break;
    }
}
#endif

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

#if TARGET_OS_IOS
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
#endif

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
        case PATH_TAG:
        {
            [self.localSettings setObject:textField.text forKey:@"path"];
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
    [self.tableView reloadData];
}

- (void)saveButtonAction {
    [textCellProfile resignFirstResponder];
    [textCellAddress resignFirstResponder];
    [textCellUsername resignFirstResponder];
    [textCellPassword resignFirstResponder];
    
    self.userAccount.settings = [NSDictionary dictionaryWithDictionary:self.localSettings];

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

