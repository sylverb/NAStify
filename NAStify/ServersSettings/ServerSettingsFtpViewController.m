//
//  ServerSettingsFtpViewController
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServerSettingsFtpViewController.h"
#import "UserAccount.h"
#import "SSKeychain.h"

#if TARGET_OS_IOS
#define SECTION_NAME_INDEX              0
#define SECTION_PROTOCOL_INDEX          1
#define SECTION_SERVER_INDEX            2
#define SECTION_AUTHENTICATION_INDEX    3
#define SECTION_TRANSFERT_MODE_INDEX    4
#define SECTION_CERTIFICATES_INDEX      5
#define SECTION_CODING_INDEX            6
#define SECTION_SAVE_INDEX              7
#elif TARGET_OS_TV
#define SECTION_NAME_INDEX              0
#define SECTION_PROTOCOL_INDEX          1
#define SECTION_SERVER_INDEX            2
#define SECTION_AUTHENTICATION_INDEX    3
#define SECTION_TRANSFERT_MODE_INDEX    4
#define SECTION_CODING_INDEX            5
#define SECTION_SAVE_INDEX              6
#endif
typedef enum _SETTINGS_TAG
{
    ADDRESS_TAG = 0,
    PORT_TAG,
    PROTOCOL_TAG,
    UNAME_TAG,
    PWD_TAG,
    ACCOUNT_NAME_TAG,
    AUTHENTICATION_TYPE_TAG,
    PRIVATE_KEY_TAG,
    PUBLIC_KEY_TAG,
    ACCEPT_UNTRUSTED_CERT_TAG,
    TRANSFERT_MODE_TAG,
} SETTINGS_TAG;

#if TARGET_OS_IOS
#define PROTOCOL_SEGMENT_FTP    0
#define PROTOCOL_SEGMENT_FTPS   1
#define PROTOCOL_SEGMENT_SFTP   2
#elif TARGET_OS_TV
#define PROTOCOL_SEGMENT_FTP    0
#define PROTOCOL_SEGMENT_SFTP   1
#endif
#define AUTHENTICATION_SEGMENT_PASSWORD     0
#define AUTHENTICATION_SEGMENT_CERTIFICATE  1

#define TRANSFERT_MODE_SEGMENT_PASSIVE      0
#define TRANSFERT_MODE_SEGMENT_ACTIVE       1

@implementation ServerSettingsFtpViewController

@synthesize textCellProfile, textCellAddress, textCellPort, textCellUsername, textCellPassword;
@synthesize userAccount, accountIndex;
#if TARGET_OS_IOS
@synthesize textViewCellPrivateCert, textViewCellPublicCert;
#endif

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index
{
    if ((self = [super initWithStyle:style])) {
        self.userAccount = account;
        self.accountIndex = index;
        
        // If it's a new account, create a new one
        if (self.accountIndex == -1) {
            self.userAccount = [[UserAccount alloc] init];
            self.userAccount.authenticationType = AUTHENTICATION_TYPE_PASSWORD;
            self.userAccount.encoding = @"UTF-8";
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

#if TARGET_OS_TV
    self.tableView.layoutMargins = UIEdgeInsetsMake(0, 90, 0, 90);
    self.invisibleTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.invisibleTextField.delegate = self;
    [self.view addSubview:self.invisibleTextField];
#endif

    // Coding options
    self.codingOptions = [NSArray arrayWithObjects:
                          // European languages
                          @"ASCII",
                          @"Western European (ISO-8859-1)",
                          @"Central European (ISO-8859-2)",
                          @"Southern European (ISO-8859-3)",
                          @"Baltic (ISO-8859-4)",
                          @"Cyrillic (ISO-8859-5)",
                          @"Greek (ISO-8859-7)",
                          @"Turkish (ISO-8859-9)",
                          @"Nordic (ISO-8859-10)",
                          @"Baltic (ISO-8859-13)",
                          @"Celtic (ISO-8859-14)",
                          @"Western European (ISO-8859-15)",
                          @"Romanian (ISO-8859-16)",
                          @"Central European (Windows-1250)",
                          @"Cyrillic (Windows-1251)",
                          @"Western European (Windows-1252)",
                          @"Greek (Windows-1253)",
                          @"Turkish (Windows-1254)",
                          @"Baltic (Windows-1257)",
                          @"Latin-1 (CP850)",
                          @"Cyrillic (CP866)",
                          @"MacRoman",
                          @"MacCentralEurope",
                          @"MacIceland",
                          @"MacCroatian",
                          @"MacRomania",
                          @"MacCyrillic",
                          @"MacUkraine",
                          @"MacGreek",
                          @"MacTurkish",
                          @"Macintosh",
                          // Semitic languages
                          @"Arabic (ISO-8859-6)",
                          @"Hebrew (ISO-8859-8)",
                          @"Hebrew (Windows-1255)",
                          @"Arabic (Windows-1256)",
                          @"MacHebrew",
                          @"MacArabic",
                          // Japanese
                          @"Japanese (EUC-JP)",
                          @"SHIFT_JIS",
                          @" (Windows-932)",
                          @"Japanese (ISO-2022-JP)",
                          @"Japanese (ISO-2022-JP-2)",
                          @"Japanese (ISO-2022-JP-1)",
                          // Chinese
                          @"EUC-CN",
                          @"HZ",
                          @"Chinese Simplified (GBK)",
                          @"CP936",
                          @"Chinese Simplified (GB18030)",
                          @"EUC-TW",
                          @"Chinese Traditional (BIG5)",
                          @"Chinese Traditional (BIG5-HKSCS)",
                          @"ISO-2022-CN",
                          @"ISO-2022-CN-EXT",
                          // Korean
                          @"EUC-KR",
                          @"CP949",
                          @"ISO-2022-KR",
                          @"JOHAB",
                          // Unicode
                          @"Unicode 8 (UTF-8)",
                          @"UCS-2",
                          @"UCS-2BE",
                          @"UCS-2LE",
                          @"UCS-4",
                          @"UCS-4BE",
                          @"UCS-4LE",
                          @"UTF-16",
                          @"UTF-16BE",
                          @"UTF-16LE",
                          @"UTF-32",
                          @"UTF-32BE",
                          @"UTF-32LE",
                          @"UTF-7",
                          @"C99",
                          @"JAVA",
                          nil];
    self.curlCoding = [NSArray arrayWithObjects:
                       // European languages
                       @"ASCII",
                       @"ISO-8859-1",
                       @"ISO-8859-2",
                       @"ISO-8859-3",
                       @"ISO-8859-4",
                       @"ISO-8859-5",
                       @"ISO-8859-7",
                       @"ISO-8859-9",
                       @"ISO-8859-10",
                       @"ISO-8859-13",
                       @"ISO-8859-14",
                       @"ISO-8859-15",
                       @"ISO-8859-16",
                       @"CP1250",
                       @"CP1251",
                       @"CP1252",
                       @"CP1253",
                       @"CP1254",
                       @"CP1257",
                       @"CP850",
                       @"CP866",
                       @"MacRoman",
                       @"MacCentralEurope",
                       @"MacIceland",
                       @"MacCroatian",
                       @"MacRomania",
                       @"MacCyrillic",
                       @"MacUkraine",
                       @"MacGreek",
                       @"MacTurkish",
                       @"Macintosh",
                       // Semitic languages
                       @"ISO-8859-6",
                       @"ISO-8859-8",
                       @"CP1255",
                       @"CP1256",
                       @"MacHebrew",
                       @"MacArabic",
                       // Japanese
                       @"EUC-JP",
                       @"SHIFT_JIS",
                       @"CP932",
                       @"ISO-2022-JP",
                       @"ISO-2022-JP-2",
                       @"ISO-2022-JP-1",
                       // Chinese
                       @"EUC-CN",
                       @"HZ",
                       @"GBK",
                       @"CP936",
                       @"GB18030",
                       @"EUC-TW",
                       @"BIG5",
                       @"BIG5-HKSCS",
                       @"ISO-2022-CN",
                       @"ISO-2022-CN-EXT",
                       // Korean
                       @"EUC-KR",
                       @"CP949",
                       @"ISO-2022-KR",
                       @"JOHAB",
                       // Unicode
                       @"UTF-8",
                       @"UCS-2",
                       @"UCS-2BE",
                       @"UCS-2LE",
                       @"UCS-4",
                       @"UCS-4BE",
                       @"UCS-4LE",
                       @"UTF-16",
                       @"UTF-16BE",
                       @"UTF-16LE",
                       @"UTF-32",
                       @"UTF-32BE",
                       @"UTF-32LE",
                       @"UTF-7",
                       @"C99",
                       @"JAVA",
                       nil];
    
    self.codingIndex = 0;
    for (self.codingIndex = 0; self.codingIndex < [self.curlCoding count]; self.codingIndex++)
    {
        if ([[self.curlCoding objectAtIndex:self.codingIndex] isEqualToString:self.userAccount.encoding])
        {
            break;
        }
    }
    
    self.navigationItem.title = NSLocalizedString(@"Settings",nil);
    
    self.localPassword = [SSKeychain passwordForService:self.userAccount.uuid account:@"password"];
    self.localPubCert = [SSKeychain passwordForService:self.userAccount.uuid account:@"pubCert"];
    self.localPrivCert = [SSKeychain passwordForService:self.userAccount.uuid account:@"privCert"];
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
    return 7;
#else
    return 7;
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
        case SECTION_PROTOCOL_INDEX:
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
            if (self.userAccount.authenticationType == AUTHENTICATION_TYPE_CERTIFICATE)
            {
                numberOfRows = 4;
            }
            else
            {
                numberOfRows = 3;
            }
            break;
        }
        case SECTION_TRANSFERT_MODE_INDEX:
        {
            if (self.userAccount.serverType == SERVER_TYPE_FTP)
            {
                numberOfRows = 1;
            }
            break;
        }
#if TARGET_OS_IOS
        case SECTION_CERTIFICATES_INDEX:
        {
            if ((self.userAccount.serverType == SERVER_TYPE_FTP) &&
                (self.userAccount.boolSSL == TRUE))
            {
                numberOfRows = 1;
            }
            else
            {
                numberOfRows = 0;
            }
            break;
        }
#endif
        case SECTION_CODING_INDEX:
        {
            if (self.userAccount.serverType == SERVER_TYPE_FTP)
            {
                numberOfRows = 1;
            }
            else
            {
                numberOfRows = 0;
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString * title = nil;
    switch (section)
    {
        case SECTION_NAME_INDEX:
        {
            break;
        }
        case SECTION_PROTOCOL_INDEX:
        {
            title = NSLocalizedString(@"Protocol",nil);
            break;
        }
        case SECTION_SERVER_INDEX:
        {
            title = NSLocalizedString(@"Server address",nil);
            break;
        }
        case SECTION_AUTHENTICATION_INDEX:
        {
            title = NSLocalizedString(@"Authentication",nil);
            break;
        }
        case SECTION_TRANSFERT_MODE_INDEX:
        {
            if (self.userAccount.serverType == SERVER_TYPE_FTP)
            {
                title = NSLocalizedString(@"Transfert mode", nil);
            }
            break;
        }
#if TARGET_OS_IOS
        case SECTION_CERTIFICATES_INDEX:
        {
            if ((self.userAccount.serverType == SERVER_TYPE_FTP) &&
                (self.userAccount.boolSSL == TRUE))
            {
                title = NSLocalizedString(@"Certificate",nil);
            }
            break;
        }
#endif
        case SECTION_CODING_INDEX:
        {
            if (self.userAccount.serverType == SERVER_TYPE_FTP)
            {
                title = NSLocalizedString(@"Coding",nil);
            }
            break;
        }
    }
    return title;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
#if TARGET_OS_IOS
    static NSString *TextCellIdentifier = @"TextCell";
    static NSString *TextViewCellIdentifier = @"TextViewCell";
    static NSString *SwitchCellIdentifier = @"SwitchCell";
    static NSString *SegmentedControllerCellIdentifier = @"SegmentedControllerCell";
    static NSString *SegmentedControllerCell2Identifier = @"SegmentedControllerCell2";
    static NSString *SegmentedControllerCell3Identifier = @"SegmentedControllerCell3";
#elif TARGET_OS_TV
    static NSString *CellIdentifier1 = @"Cell1";
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
                    [textCellProfile setCellDataWithLabelString:NSLocalizedString(@"Profile Name:",nil)
                                                withText:userAccount.accountName
                                         withPlaceHolder:NSLocalizedString(@"Description",nil)
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
        case SECTION_PROTOCOL_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
#if TARGET_OS_IOS
                    NSInteger selectedIndex = PROTOCOL_SEGMENT_FTP;
                    self.protocolSegCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedControllerCellIdentifier];
                    if (self.protocolSegCtrlCell == nil)
                    {
                        self.protocolSegCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                      reuseIdentifier:SegmentedControllerCellIdentifier
                                                                            withItems:[NSArray arrayWithObjects:
                                                                                       NSLocalizedString(@"FTP",nil),
                                                                                       NSLocalizedString(@"FTPS",nil),
                                                                                       NSLocalizedString(@"SFTP",nil),
                                                                                       nil]];
                    }
                    
                    if (self.userAccount.serverType == SERVER_TYPE_SFTP)
                    {
                        selectedIndex = PROTOCOL_SEGMENT_SFTP;
                    }
                    else if (self.userAccount.boolSSL == TRUE)
                    {
                        selectedIndex = PROTOCOL_SEGMENT_FTPS;
                    }
                    
                    [self.protocolSegCtrlCell setCellDataWithLabelString:NSLocalizedString(@"Protocol:",nil)
                                                       withSelectedIndex:selectedIndex
                                                                  andTag:PROTOCOL_TAG];
                    
                    [self.protocolSegCtrlCell.segmentedControl addTarget:self action:@selector(segmentedValueChanged:) forControlEvents:UIControlEventValueChanged];
                    
                    cell = self.protocolSegCtrlCell;
#elif TARGET_OS_TV
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Protocol",nil);
                    if (self.userAccount.serverType == SERVER_TYPE_FTP)
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"FTP",nil);
                    }
                    else
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"SFTP",nil);
                    }
#endif
                    break;
                }
                default:
                {
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
                    [textCellAddress setCellDataWithLabelString:NSLocalizedString(@"Address:",nil)
                                                withText:userAccount.server
                                         withPlaceHolder:NSLocalizedString(@"Hostname or IP",nil)
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
                    [textCellPort setCellDataWithLabelString:NSLocalizedString(@"Port:",nil)
                                                withText:userAccount.port
                                         withPlaceHolder:NSLocalizedString(@"Port number",nil)
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
                    NSInteger selectedIndex = AUTHENTICATION_SEGMENT_PASSWORD;
                    SegCtrlCell *segCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedControllerCell2Identifier];
                    if (segCtrlCell == nil)
                    {
                        segCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:SegmentedControllerCell2Identifier
                                                               withItems:[NSArray arrayWithObjects:
                                                                          NSLocalizedString(@"Password",nil),
                                                                          NSLocalizedString(@"Certificate",nil),
                                                                          nil]];
                    }
                    
                    if (self.userAccount.authenticationType == AUTHENTICATION_TYPE_CERTIFICATE)
                    {
                        selectedIndex = AUTHENTICATION_SEGMENT_CERTIFICATE;
                    }
                    else
                    {
                        selectedIndex = AUTHENTICATION_SEGMENT_PASSWORD;
                    }
                    
                    [segCtrlCell setCellDataWithLabelString:NSLocalizedString(@"Type:",nil)
                                          withSelectedIndex:selectedIndex
                                                     andTag:AUTHENTICATION_TYPE_TAG];
                    
                    [segCtrlCell.segmentedControl addTarget:self action:@selector(segmentedValueChanged:) forControlEvents:UIControlEventValueChanged];
                    
                    cell = segCtrlCell;
#elif TARGET_OS_TV
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Type",nil);
                    cell.detailTextLabel.text = NSLocalizedString(@"Password",nil);
#endif
                    break;
                }
                case 1:
                {
#if TARGET_OS_IOS
                    textCellUsername = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCellUsername == nil)
                    {
                        textCellUsername = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                           reuseIdentifier:TextCellIdentifier];
                    }
                    [textCellUsername setCellDataWithLabelString:NSLocalizedString(@"Username:",nil)
                                                        withText:userAccount.userName
                                                 withPlaceHolder:NSLocalizedString(@"Username",nil)
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
                case 2:
                {
                    if (self.userAccount.authenticationType == AUTHENTICATION_TYPE_PASSWORD)
                    {
#if TARGET_OS_IOS
                        textCellPassword = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                        if (textCellPassword == nil)
                        {
                            textCellPassword = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                               reuseIdentifier:TextCellIdentifier];
                        }
                        [textCellPassword setCellDataWithLabelString:NSLocalizedString(@"Password:",nil)
                                                            withText:self.localPassword
                                                     withPlaceHolder:NSLocalizedString(@"Password",nil)
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
                    }
#if TARGET_OS_IOS
                    else
                    {
                        textViewCellPublicCert = (TextViewCell *)[tableView dequeueReusableCellWithIdentifier:TextViewCellIdentifier];
                        if (textViewCellPublicCert == nil)
                        {
                            textViewCellPublicCert = [[TextViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                         reuseIdentifier:TextViewCellIdentifier];
                        }
                        [textViewCellPublicCert setCellDataWithLabelString:NSLocalizedString(@"Public cert:",nil)
                                                                  withText:self.localPubCert
                                                          withKeyboardType:UIKeyboardTypeDefault
                                                              withDelegate:self
                                                                    andTag:PUBLIC_KEY_TAG];
                        cell = textViewCellPublicCert;
                        [self.tableView beginUpdates];
                        [self.tableView endUpdates];
                    }
#endif
                    break;
                }
#if TARGET_OS_IOS
                case 3:
                {
                    textViewCellPrivateCert = (TextViewCell *)[tableView dequeueReusableCellWithIdentifier:TextViewCellIdentifier];
                    if (textViewCellPrivateCert == nil)
                    {
                        textViewCellPrivateCert = [[TextViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                      reuseIdentifier:TextViewCellIdentifier];
                    }
                    [textViewCellPrivateCert setCellDataWithLabelString:NSLocalizedString(@"Private cert:",nil)
                                                               withText:self.localPrivCert
                                                       withKeyboardType:UIKeyboardTypeDefault
                                                           withDelegate:self
                                                                 andTag:PRIVATE_KEY_TAG];
                    cell = textViewCellPrivateCert;
                    [self.tableView beginUpdates];
                    [self.tableView endUpdates];
                    break;
                }
#endif
            }
            break;
        }
        case SECTION_TRANSFERT_MODE_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
#if TARGET_OS_IOS
                    NSInteger selectedIndex;
                    self.transfertModeSegCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedControllerCell3Identifier];
                    if (self.transfertModeSegCtrlCell == nil)
                    {
                        self.transfertModeSegCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                           reuseIdentifier:SegmentedControllerCell3Identifier
                                                                                 withItems:[NSArray arrayWithObjects:
                                                                                            NSLocalizedString(@"Passive",nil),
                                                                                            NSLocalizedString(@"Active",nil),
                                                                                            nil]];
                    }
                    
                    if (self.userAccount.transfertMode == TRANSFERT_MODE_FTP_PASSIVE)
                    {
                        selectedIndex = TRANSFERT_MODE_SEGMENT_PASSIVE;
                    }
                    else
                    {
                        selectedIndex = TRANSFERT_MODE_SEGMENT_ACTIVE;
                    }
                    
                    [self.transfertModeSegCtrlCell setCellDataWithLabelString:NSLocalizedString(@"Mode:",nil)
                                                            withSelectedIndex:selectedIndex
                                                                       andTag:TRANSFERT_MODE_TAG];
                    
                    [segCtrlCell.segmentedControl addTarget:self action:@selector(segmentedValueChanged:) forControlEvents:UIControlEventValueChanged];
                    
                    cell = self.transfertModeSegCtrlCell;
#elif TARGET_OS_TV
                    cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                      reuseIdentifier:CellIdentifier1];
                    }
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    cell.textLabel.text = NSLocalizedString(@"Mode",nil);
                    if (self.userAccount.transfertMode == TRANSFERT_MODE_FTP_PASSIVE)
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"Passive",nil);
                    }
                    else
                    {
                        cell.detailTextLabel.text = NSLocalizedString(@"Active",nil);
                    }
#endif
                    break;
                }
            }
            break;
        }
#if TARGET_OS_IOS
        case SECTION_CERTIFICATES_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
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
                    break;
                }
            }
            break;
        }
#endif
        case SECTION_CODING_INDEX:
        {
#if TARGET_OS_IOS
            cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (cell == nil)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:CellIdentifier];
            }
            cell.textLabel.text = [self.codingOptions objectAtIndex:self.codingIndex];
#elif TARGET_OS_TV
            cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier1];
            if (cell == nil)
            {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                              reuseIdentifier:CellIdentifier1];
            }
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.textLabel.text = NSLocalizedString(@"Text coding",nil);
            cell.detailTextLabel.text = [self.codingOptions objectAtIndex:self.codingIndex];
#endif
            break;
        }
#if TARGET_OS_TV
        case SECTION_SAVE_INDEX:
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
                    self.invisibleTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter server IP or domain name (without ftp:// or sftp://)"];
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
            

#if TARGET_OS_TV
        case SECTION_PROTOCOL_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
#if TARGET_OS_IOS
                    self.protocolSegCtrlCell.segmentedControl.selectedSegmentIndex = (self.protocolSegCtrlCell.segmentedControl.selectedSegmentIndex + 1)%3;
                    switch (self.protocolSegCtrlCell.segmentedControl.selectedSegmentIndex)
                    {
                        case PROTOCOL_SEGMENT_FTP:
                        {
                            self.userAccount.serverType = SERVER_TYPE_FTP;
                            self.userAccount.boolSSL = FALSE;
                            break;
                        }
                        case PROTOCOL_SEGMENT_FTPS:
                        {
                            self.userAccount.serverType = SERVER_TYPE_FTP;
                            self.userAccount.boolSSL = TRUE;
                            break;
                        }
                        case PROTOCOL_SEGMENT_SFTP:
                        {
                            self.userAccount.serverType = SERVER_TYPE_SFTP;
                            break;
                        }
                    }
#elif TARGET_OS_TV
                    if (self.userAccount.serverType == SERVER_TYPE_FTP)
                    {
                        self.userAccount.serverType = SERVER_TYPE_SFTP;
                    }
                    else
                    {
                        self.userAccount.serverType = SERVER_TYPE_FTP;
                    }
#endif
                    [self.tableView reloadData];
                    break;
                }
                default:
                {
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
                    if (self.userAccount.authenticationType == AUTHENTICATION_TYPE_PASSWORD)
                    {
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil)
                                                                                       message:NSLocalizedString(@"Certificate input is not supported on AppleTV", nil)
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                        
                        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK",nil)
                                                                                style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction * action) {
                                                                              }];
                        [alert addAction:defaultAction];
                        [self presentViewController:alert animated:YES completion:nil];
                    }
                    else
                    {
                        self.userAccount.authenticationType = AUTHENTICATION_TYPE_PASSWORD;
                    }
                    [self.tableView reloadData];
#endif
                    break;
                }
                case 1:
                {
                    self.invisibleTextField.text = userAccount.userName;
                    self.invisibleTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Enter username"];
                    self.invisibleTextField.keyboardType = UIKeyboardTypeDefault;
                    self.invisibleTextField.secureTextEntry = NO;
                    self.invisibleTextField.tag = UNAME_TAG;
                    [self.invisibleTextField becomeFirstResponder];
                    break;
                }
                case 2:
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
                {
                    break;
                }
            }
            break;
        }
        case SECTION_TRANSFERT_MODE_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
#if TARGET_OS_IOS
                    switch (self.transfertModeSegCtrlCell.segmentedControl.selectedSegmentIndex)
                    {
                        case TRANSFERT_MODE_SEGMENT_ACTIVE:
                        {
                            self.userAccount.transfertMode = TRANSFERT_MODE_FTP_PASSIVE;
                            break;
                        }
                        case TRANSFERT_MODE_SEGMENT_PASSIVE:
                        {
                            self.userAccount.transfertMode = TRANSFERT_MODE_FTP_ACTIVE;
                            break;
                        }
                    }
#elif TARGET_OS_TV
                    if (self.userAccount.transfertMode == TRANSFERT_MODE_FTP_PASSIVE)
                    {
                        self.userAccount.transfertMode = TRANSFERT_MODE_FTP_ACTIVE;
                    }
                    else
                    {
                        self.userAccount.transfertMode = TRANSFERT_MODE_FTP_PASSIVE;
                    }
#endif
                    [self.tableView reloadData];
                    break;
                }
                default:
                {
                    break;
                }
            }
            break;
        }
#endif
        case SECTION_CODING_INDEX:
        {
#if TARGET_OS_IOS
            TableSelectViewController *tableSelectViewController;
            if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ||
                (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomTV))
            {
                tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStylePlain];
            }
            else
            {
                tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStyleGrouped];
            }
            tableSelectViewController.elements = self.codingOptions;
            tableSelectViewController.selectedElement = self.codingIndex;
            tableSelectViewController.delegate = self;
            
#if 0
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            {
                CGRect rect = button.frame;
                self.sortingOptionPopoverController = [[UIPopoverController alloc] initWithContentViewController:tableSelectViewController];
                self.sortingOptionPopoverController.popoverContentSize = CGSizeMake(320.0, MIN([self.codingOptions count] * 44.0,700));
                [self.sortingOptionPopoverController presentPopoverFromRect:rect
                                                                     inView:button.superview
                                                   permittedArrowDirections:UIPopoverArrowDirectionDown|UIPopoverArrowDirectionUp|UIPopoverArrowDirectionRight
                                                                   animated:YES];
            }
            else
#endif
            {
                [self presentViewController:tableSelectViewController animated:YES completion:nil];
            }
#elif TARGET_OS_TV
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Network Caching Level",nil)
                                                                           message:nil
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            NSInteger index = 0;
            for (NSString *element in self.codingOptions)
            {
                UIAlertAction *action = [UIAlertAction actionWithTitle:element
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * action) {
                                                                   self.codingIndex = index;
                                                                   [alert dismissViewControllerAnimated:YES completion:nil];
                                                                   [self.tableView reloadData];
                                                               }];
                [alert addAction:action];
                if (index == self.codingIndex)
                {
                    alert.preferredAction = action;
                }
                index++;
            }
            UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               [alert dismissViewControllerAnimated:YES completion:nil];
                                                           }];
            [alert addAction:cancel];

            [self presentViewController:alert animated:YES completion:nil];
#endif
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
    }
}

#if TARGET_OS_IOS
- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ((indexPath.section == SECTION_AUTHENTICATION_INDEX) &&
        (indexPath.row == 2) &&
        (self.userAccount.authenticationType == AUTHENTICATION_TYPE_CERTIFICATE))
    {
        CGSize textViewSize = [self.textViewCellPublicCert.textView sizeThatFits:CGSizeMake(self.textViewCellPublicCert.textView.frame.size.width, FLT_MAX)];
        if (textViewSize.height >= 69.0f)
        {
             CGRect frame = self.textViewCellPublicCert.textView.frame;
             frame.size.height = textViewSize.height;
             [self.textViewCellPublicCert.textView setFrame:frame];

            float height = textViewSize.height + self.textViewCellPublicCert.label.frame.size.height;
            return height + 8; // a little extra padding is needed
        }
        else
        {
            return 69.0f;
        }
    }
    else if ((indexPath.section == SECTION_AUTHENTICATION_INDEX) &&
             (indexPath.row == 3))
    {
        CGSize textViewSize = [self.textViewCellPrivateCert.textView sizeThatFits:CGSizeMake(self.textViewCellPrivateCert.textView.frame.size.width, FLT_MAX)];
        if (textViewSize.height >= 69.0f)
        {
            CGRect frame = self.textViewCellPrivateCert.textView.frame;
            frame.size.height = textViewSize.height;
            [self.textViewCellPrivateCert.textView setFrame:frame];
            
            float height = textViewSize.height + self.textViewCellPrivateCert.label.frame.size.height;
            return height + 8; // a little extra padding is needed
        }
        else
        {
            return 69.0f;
        }
    }
    else
    {
        return self.tableView.rowHeight;
    }
}
#endif

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
                case SERVER_TYPE_FTP:
                case SERVER_TYPE_SFTP:
                {
                    if ([textField.text hasPrefix:@"ftp://"])
                    {
                        textField.text = [[textField.text substringFromIndex:6] stringByReplacingOccurrencesOfString:@" " withString:@""];
                        self.userAccount.serverType = SERVER_TYPE_FTP;
                        self.userAccount.boolSSL = NO;
                    }
#if TARGET_OS_IOS
                    else if ([textField.text hasPrefix:@"ftps://"])
                    {
                        textField.text = [[textField.text substringFromIndex:7] stringByReplacingOccurrencesOfString:@" " withString:@""];
                        self.userAccount.serverType = SERVER_TYPE_FTP;
                        self.userAccount.boolSSL = YES;
                    }
#endif
                    else if ([textField.text hasPrefix:@"sftp://"])
                    {
                        textField.text = [[textField.text substringFromIndex:7] stringByReplacingOccurrencesOfString:@" " withString:@""];
                        self.userAccount.serverType = SERVER_TYPE_SFTP;
                        self.userAccount.boolSSL = NO;
                    }
                    else
                    {
                        textField.text = [textField.text stringByReplacingOccurrencesOfString:@" " withString:@""];
                    }
                    textField.text = [textField.text stringByReplacingOccurrencesOfString:@"/" withString:@""];
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

- (void)saveButtonAction
{
    [textCellProfile resignFirstResponder];
    [textCellAddress resignFirstResponder];
    [textCellPort resignFirstResponder];
    [textCellUsername resignFirstResponder];
    [textCellPassword resignFirstResponder];
#if TARGET_OS_IOS
    [textViewCellPrivateCert resignFirstResponder];
    [textViewCellPublicCert resignFirstResponder];
#endif
    
    // Save secret information in keychain
    [SSKeychain setPassword:self.localPassword
                 forService:self.userAccount.uuid
                    account:@"password"];
    [SSKeychain setPassword:self.localPubCert
                 forService:self.userAccount.uuid
                    account:@"pubCert"];
    [SSKeychain setPassword:self.localPrivCert
                 forService:self.userAccount.uuid
                    account:@"privCert"];

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
        case ACCEPT_UNTRUSTED_CERT_TAG:
        {
            self.userAccount.acceptUntrustedCertificate = [sender isOn];
            break;
        }
    }
    [self.tableView reloadData];
}
#endif

#if TARGET_OS_IOS
- (void)segmentedValueChanged:(id)sender {
	NSInteger tag = ((UISegmentedControl *)sender).tag;
	switch (tag)
    {
		case PROTOCOL_TAG:
        {
            switch ([sender selectedSegmentIndex])
            {
                case PROTOCOL_SEGMENT_FTP:
                {
                    self.userAccount.serverType = SERVER_TYPE_FTP;
                    self.userAccount.boolSSL = NO;
                    self.userAccount.authenticationType = AUTHENTICATION_TYPE_PASSWORD;
                    break;
                }
                case PROTOCOL_SEGMENT_FTPS:
                {
                    self.userAccount.serverType = SERVER_TYPE_FTP;
                    self.userAccount.boolSSL = YES;
                    self.userAccount.authenticationType = AUTHENTICATION_TYPE_PASSWORD;
                    break;
                }
                case PROTOCOL_SEGMENT_SFTP:
                {
                    self.userAccount.serverType = SERVER_TYPE_SFTP;
                    self.userAccount.boolSSL = NO;
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case TRANSFERT_MODE_TAG:
        {
            switch ([sender selectedSegmentIndex])
            {
                case TRANSFERT_MODE_SEGMENT_PASSIVE:
                {
                    self.userAccount.transfertMode = TRANSFERT_MODE_FTP_PASSIVE;
                    break;
                }
                case TRANSFERT_MODE_SEGMENT_ACTIVE:
                {
                    self.userAccount.transfertMode = TRANSFERT_MODE_FTP_ACTIVE;
                    break;
                }
            }
            break;
        }
        case AUTHENTICATION_TYPE_TAG:
        {
            switch ([sender selectedSegmentIndex])
            {
                case AUTHENTICATION_SEGMENT_PASSWORD:
                {
                    self.userAccount.authenticationType = AUTHENTICATION_TYPE_PASSWORD;
                    break;
                }
                case AUTHENTICATION_SEGMENT_CERTIFICATE:
                {
                    if (self.userAccount.serverType == SERVER_TYPE_SFTP)
                    {
                        self.userAccount.authenticationType = AUTHENTICATION_TYPE_CERTIFICATE;
                    }
                    else
                    {
                        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Authentication",nil)
                                                    message:NSLocalizedString(@"This is only available for SFTP protocol",nil)
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK",nil)
                                          otherButtonTitles:nil]
                         show];
                    }
                    break;
                }
                default:
                    break;
            }
            break;
        }
	}
    [self.tableView reloadData];
}
#endif

- (void)textViewDidChange:(UITextView *)textView
{
    switch (textView.tag)
    {
        case PRIVATE_KEY_TAG:
        {
            self.localPrivCert = textView.text;
            break;
        }
        case PUBLIC_KEY_TAG:
        {
            self.localPubCert = textView.text;
            break;
        }
    }
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}

- (void)selectedElementIndex:(NSInteger)elementIndex forTag:(NSInteger)tag
{
    self.userAccount.encoding = [self.curlCoding objectAtIndex:elementIndex];
    self.codingIndex = elementIndex;
    [self.tableView reloadData];
}

@end

