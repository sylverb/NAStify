//
//  ServerSettingsSynologyViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TextCell.h"
#import "UserAccount.h"

@interface ServerSettingsSynologyViewController : UITableViewController<UITextFieldDelegate>
{
    @private
    UserAccount * userAccount;
    NSInteger    accountIndex;
    
    TextCell * textCellProfile;
    TextCell * textCellAddress;
    TextCell * textCellPort;
    TextCell * textCellUsername;
    TextCell * textCellPassword;
}

@property(nonatomic, copy) UserAccount * userAccount;
@property(nonatomic, strong) TextCell * textCellProfile;
@property(nonatomic, strong) TextCell * textCellAddress;
@property(nonatomic, strong) TextCell * textCellPort;
@property(nonatomic, strong) TextCell * textCellUsername;
@property(nonatomic, strong) TextCell * textCellPassword;
@property(nonatomic, strong) TextCell * textCellOTP;
@property(nonatomic) NSInteger    accountIndex;
@property(nonatomic, strong) NSString *localPassword;
@property(nonatomic, strong) NSString *localOTPSecCode;

@property(nonatomic, strong) id currentFirstResponder;
#if TARGET_OS_TV
@property(nonatomic, strong) UITextField *invisibleTextField;
#endif

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index;
#if TARGET_OS_IOS
- (void)switchValueChanged:(id)sender;
#endif
@end
