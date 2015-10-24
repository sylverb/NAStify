//
//  TVServerSettingsSynologyViewController.m
//  NAStify
//
//  Created by Sylver B on 22/10/15.
//  Copyright © 2015 CodeIsALie. All rights reserved.
//

#import "TVServerSettingsSynologyViewController.h"
#import "SSkeychain.h"

@interface TVServerSettingsSynologyViewController ()

@end

@implementation TVServerSettingsSynologyViewController

- (id)initWithAccount:(UserAccount *)account andIndex:(NSInteger)index
{
    if ((self = [super init]))
    {
        self.userAccount = account;
        self.accountIndex = index;
        
        // If it's a new account, create a new one
        if (self.accountIndex == -1)
        {
            self.userAccount = [[UserAccount alloc] init];
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Init localPassword with keychain content
    self.localPassword = [SSKeychain passwordForService:self.userAccount.uuid account:@"password"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.textCellProfile.text = self.userAccount.accountName;
    self.textCellAddress.text = self.userAccount.server;
    self.textCellPort.text = self.userAccount.port;
    self.textCellUsername.text = self.userAccount.userName;
    self.textCellPassword.text = [SSKeychain passwordForService:self.userAccount.uuid account:@"password"];
    if (self.accountIndex == -1)
    {
        self.ButtonAdd.titleLabel.text = NSLocalizedString(@"Add", nil);
    }
    else
    {
        self.ButtonAdd.titleLabel.text = NSLocalizedString(@"Update", nil);
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == self.textCellProfile)
    {
        self.userAccount.accountName = textField.text;
    }
    else if (textField == self.textCellAddress)
    {
        self.userAccount.server = textField.text;
    }
    else if (textField == self.textCellPort)
    {
        self.userAccount.port = textField.text;
    }
    else if (textField == self.textCellUsername)
    {
        self.userAccount.userName = textField.text;
    }
    else if (textField == self.textCellPassword)
    {
        self.localPassword = textField.text;
    }
}

#pragma mark - UIButton management

- (IBAction)addButtonPressed
{
    [SSKeychain setPassword:self.localPassword
                 forService:self.userAccount.uuid
                    account:@"password"];
    
    if (self.accountIndex == -1)
    {
        NSNotification* notification = [NSNotification notificationWithName:@"ADDACCOUNT"
                                                                     object:self
                                                                   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self.userAccount,@"account",nil]];
        
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
    }
    else
    {
        NSNotification* notification = [NSNotification notificationWithName:@"UPDATEACCOUNT"
                                                                     object:self
                                                                   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self.userAccount,@"account",[NSNumber numberWithLong:self.accountIndex],@"accountIndex",nil]];
        
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
    }
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
