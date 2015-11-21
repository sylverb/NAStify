//
//  ServerSettingsWebDavViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TextCell.h"
#if TARGET_OS_IOS
#import "SwitchCell.h"
#elif TARGET_OS_TV
#import "SegCtrlCell.h"
#endif
#import "UserAccount.h"

@interface ServerSettingsWebDavViewController : UITableViewController<UITextFieldDelegate>

@property(nonatomic, copy) UserAccount * userAccount;
@property(nonatomic, strong) TextCell * textCellProfile;
@property(nonatomic, strong) TextCell * textCellAddress;
@property(nonatomic, strong) TextCell * textCellPort;
@property(nonatomic, strong) TextCell * textCellPath;
@property(nonatomic, strong) TextCell * textCellUsername;
@property(nonatomic, strong) TextCell * textCellPassword;
@property(nonatomic) NSInteger    accountIndex;
@property(nonatomic, strong) NSString *localPassword;
@property(nonatomic, strong) NSMutableDictionary *localSettings;

@property(nonatomic, strong) id currentFirstResponder;
#if TARGET_OS_TV
@property(nonatomic, strong) UITextField *invisibleTextField;
#endif

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index;
#if TARGET_OS_IOS
- (void)switchValueChanged:(id)sender;
#endif
@end
