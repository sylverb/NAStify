//
//  ServerSettingsQnapViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServerSettingsQnapViewController.h"
#import "UserAccount.h"
#import "SSKeychain.h"

typedef enum _SETTINGS_TAG
{
    ADDRESS_TAG = 0,
    PORT_TAG,
    UNAME_TAG,
    PWD_TAG,
    ACCOUNT_NAME_TAG,
    SSL_TAG,
    ACCEPT_UNTRUSTED_CERT_TAG
} SETTINGS_TAG;

@implementation ServerSettingsQnapViewController

@synthesize textCellProfile, textCellAddress, textCellPort, textCellUsername, textCellPassword;
@synthesize userAccount, accountIndex;

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index
{
    if ((self = [super initWithStyle:style])) {
        self.userAccount = account;
        self.accountIndex = index;
        
        // If it's a new account, create a new one
        if (self.accountIndex == -1) {
            userAccount = [[UserAccount alloc] init];
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
#if TARGET_OS_IOS
    return 4;
#else
    return 5;
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
        case 3:
        {
            if (self.userAccount.boolSSL)
            {
                numberOfRows = 2;
            }
            else
            {
                numberOfRows = 1;
            }
            break;
        }
#if TARGET_OS_TV
            case 4:
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
#if TARGET_OS_IOS
    static NSString *SwitchCellIdentifier = @"SwitchCell";
#elif TARGET_OS_TV
    static NSString *TableCellIdentifier = @"TableCell";
    static NSString *SegmentedCellIdentifier = @"SegmentedCell";
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
                    [textCellAddress setCellDataWithLabelString:NSLocalizedString(@"Address:",@"")
                                                withText:userAccount.server
                                         withPlaceHolder:NSLocalizedString(@"Hostname or IP",@"")
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
                    [textCellPort setCellDataWithLabelString:NSLocalizedString(@"Port:",@"")
                                                withText:userAccount.port
                                         withPlaceHolder:NSLocalizedString(@"Port number",@"")
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
        case 3:
        {
            switch (indexPath.row)
            {
                case 0:
                {
#if TARGET_OS_IOS
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil)
                    {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                           reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell  setCellDataWithLabelString:NSLocalizedString(@"SSL", nil)
                                                  withState:self.userAccount.boolSSL
                                                     andTag:SSL_TAG];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
#else
                    NSInteger selectedIndex;
                    
                    SegCtrlCell *segCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedCellIdentifier];
                    if (segCtrlCell == nil)
                    {
                        segCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:SegmentedCellIdentifier
                                                               withItems:[NSArray arrayWithObjects:
                                                                          NSLocalizedString(@"Yes",nil),
                                                                          NSLocalizedString(@"No",nil),
                                                                          nil]];
                    }
                    
                    if (self.userAccount.boolSSL)
                    {
                        selectedIndex = 0;
                    }
                    else
                    {
                        selectedIndex = 1;
                    }
                    
                    [segCtrlCell setCellDataWithLabelString:NSLocalizedString(@"SSL",nil)
                                          withSelectedIndex:selectedIndex
                                                     andTag:SSL_TAG];
                    
                    cell = segCtrlCell;
#endif
                    break;
                }
                case 1:
                {
#if TARGET_OS_IOS
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil)
                    {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell  setCellDataWithLabelString:NSLocalizedString(@"Allow untrusted certificate", nil)
                                                  withState:self.userAccount.acceptUntrustedCertificate
                                                     andTag:ACCEPT_UNTRUSTED_CERT_TAG];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
#else
                    NSInteger selectedIndex;
                    
                    SegCtrlCell *segCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedCellIdentifier];
                    if (segCtrlCell == nil)
                    {
                        segCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:SegmentedCellIdentifier
                                                               withItems:[NSArray arrayWithObjects:
                                                                          NSLocalizedString(@"Yes",nil),
                                                                          NSLocalizedString(@"No",nil),
                                                                          nil]];
                    }
                    
                    if (self.userAccount.acceptUntrustedCertificate)
                    {
                        selectedIndex = 0;
                    }
                    else
                    {
                        selectedIndex = 1;
                    }
                    
                    [segCtrlCell setCellDataWithLabelString:NSLocalizedString(@"Allow untrusted certificate",nil)
                                          withSelectedIndex:selectedIndex
                                                     andTag:ACCEPT_UNTRUSTED_CERT_TAG];
                    
                    cell = segCtrlCell;
#endif
                    break;
                }
            }
            break;
        }
#if TARGET_OS_TV
        case 4:
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
        case 3:
        {
            switch (indexPath.row)
            {
                case 0: // SSL
                {
                    self.userAccount.boolSSL = !self.userAccount.boolSSL;
                    [self.tableView reloadData];
                    break;
                }
                case 1: // Certificate
                {
                    self.userAccount.acceptUntrustedCertificate = !self.userAccount.acceptUntrustedCertificate;
                    [self.tableView reloadData];
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case 4:
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
        case 3:
        {
            title = NSLocalizedString(@"Encryption",nil);
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
        [textCellPort.textField becomeFirstResponder];
    }
    else if (textField == textCellPort.textField)
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
            switch (self.userAccount.serverType)
            {
                case SERVER_TYPE_WEBDAV:
                {
                    if (([textField.text hasPrefix:@"https://"]) || ([textField.text hasPrefix:@"webdavs://"]))
                    {
                        self.userAccount.boolSSL = YES;
                    }
                    else if (([textField.text hasPrefix:@"http://"]) || ([textField.text hasPrefix:@"webdav://"]))
                    {
                        self.userAccount.boolSSL = NO;
                    }
                    [self.tableView reloadData];
                    break;
                }
                default:
                    break;
            }
            self.userAccount.server = textField.text;
            break;
        }
        case PORT_TAG:
        {
            self.userAccount.port = textField.text;
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
    [textCellPort resignFirstResponder];
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
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark UISwitch responder

#if TARGET_OS_IOS
- (void)switchValueChanged:(id)sender
{
    NSInteger tag = ((UISwitch *)sender).tag;
    switch (tag)
    {
        case SSL_TAG:
        {
            self.userAccount.boolSSL = [sender isOn];
            break;
        }
        case ACCEPT_UNTRUSTED_CERT_TAG:
        {
            self.userAccount.acceptUntrustedCertificate = [sender isOn];
            break;
        }
    }
    [self.tableView reloadData];
}
#endif

@end

