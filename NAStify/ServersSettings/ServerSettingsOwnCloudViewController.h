//
//  ServerSettingsOwnCloudViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TextCell.h"
#import "SwitchCell.h"
#import "UserAccount.h"

@interface ServerSettingsOwnCloudViewController : UITableViewController<UITextFieldDelegate>
{
@private
    UserAccount * userAccount;
    NSInteger    accountIndex;
    
    TextCell * textCellProfile;
    TextCell * textCellAddress;
    TextCell * textCellPort;
    TextCell * textCellPath;
    TextCell * textCellUsername;
    TextCell * textCellPassword;
}

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

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index;
- (void)switchValueChanged:(id)sender;

@end
