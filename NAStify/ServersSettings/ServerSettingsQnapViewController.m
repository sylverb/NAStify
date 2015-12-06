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

#define SECTION_NAME_INDEX              0
#define SECTION_SERVER_INDEX            1
#define SECTION_AUTHENTICATION_INDEX    2
#define SECTION_ENCRYPTION_INDEX        3
#define SECTION_SAVE_INDEX              4

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
        case SECTION_NAME_INDEX:
        {
            numberOfRows = 1;
            break;
        }
        case SECTION_SERVER_INDEX:
        {
            numberOfRows = 2;
            break;
        }
        case SECTION_AUTHENTICATION_INDEX:
        {
            numberOfRows = 2;
            break;
        }
        case SECTION_ENCRYPTION_INDEX:
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
            case SECTION_SAVE_INDEX:
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
    static NSString *SwitchCellIdentifier = @"SwitchCell";
#elif TARGET_OS_TV
    static NSString *CellIdentifier1 = @"Cell1";
    static NSString *TableCellIdentifier = @"TableCell";
#endif

    UITableViewCell *cell = nil;

    switch (indexPath.section)
    {
        case SECTION_NAME_INDEX:
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
        case SECTION_SERVER_INDEX:
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
                    [textCellAddress setCellDataWithLabelString:NSLocalizedString(@"Address:",@"")
                                                withText:userAccount.server
                                         withPlaceHolder:NSLocalizedString(@"Hostname or IP",@"")
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
#elif TARGET_OS_TV
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Port number",nil);
                    cell.detailTextLabel.text = userAccount.port;
#endif
                    break;
                }
            }
            break;
        }
        case SECTION_AUTHENTICATION_INDEX:
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
        case SECTION_ENCRYPTION_INDEX:
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
#elif TARGET_OS_TV
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"SSL",nil);
                    if (self.userAccount.boolSSL)
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"Yes",nil);
                    }
                    else
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"No",nil);
                    }
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
#elif TARGET_OS_TV
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Allow untrusted certificate",nil);
                    if (self.userAccount.acceptUntrustedCertificate)
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"Yes",nil);
                    }
                    else
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"No",nil);
                    }
#endif
                    break;
                }
            }
            break;
        }
#if TARGET_OS_TV
        case SECTION_SAVE_INDEX:
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
        case SECTION_NAME_INDEX:
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
        case SECTION_SERVER_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    self.invisibleTextField.text = userAccount.server;
                    self.invisibleTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter server IP/Domain name (without http:// or https://)"];
                    self.invisibleTextField.keyboardType = UIKeyboardTypeURL;
                    self.invisibleTextField.secureTextEntry = NO;
                    self.invisibleTextField.tag = ADDRESS_TAG;
                    [self.invisibleTextField becomeFirstResponder];
                    break;
                }
                case 1:
                {
                    self.invisibleTextField.text = userAccount.port;
                    self.invisibleTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter port, let blank to use default port"];
                    self.invisibleTextField.keyboardType = UIKeyboardTypeNumberPad;
                    self.invisibleTextField.secureTextEntry = NO;
                    self.invisibleTextField.tag = PORT_TAG;
                    [self.invisibleTextField becomeFirstResponder];
                    break;
                }
            }
            break;
        }
        case SECTION_AUTHENTICATION_INDEX:
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
        case SECTION_ENCRYPTION_INDEX:
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
        case SECTION_SAVE_INDEX:
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
        case SECTION_NAME_INDEX:
        {
            break;
        }
        case SECTION_SERVER_INDEX:
        {
            title = NSLocalizedString(@"Server Connection",nil);
            break;
        }
        case SECTION_AUTHENTICATION_INDEX:
        {
            title = NSLocalizedString(@"Security",nil);
            break;
        }
        case SECTION_ENCRYPTION_INDEX:
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
    [self.tableView reloadData];
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

