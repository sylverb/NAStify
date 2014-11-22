//
//  ServerSettingsSambaViewController
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2013 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TextCell.h"
#import "SwitchCell.h"
#import "UserAccount.h"

@interface ServerSettingsSambaViewController : UITableViewController<UITextFieldDelegate>
{
    @private
    UserAccount * userAccount;
    NSInteger    accountIndex;
    
    TextCell * textCellProfile;
    TextCell * textCellAddress;
    TextCell * textCellUsername;
    TextCell * textCellPassword;
}

@property(nonatomic, copy) UserAccount * userAccount;
@property(nonatomic, strong) TextCell * textCellProfile;
@property(nonatomic, strong) TextCell * textCellAddress;
@property(nonatomic, strong) TextCell * textCellUsername;
@property(nonatomic, strong) TextCell * textCellPassword;
@property(nonatomic) NSInteger    accountIndex;
@property(nonatomic, strong) NSString *localPassword;

@property(nonatomic, strong) id currentFirstResponder;

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index;

@end
