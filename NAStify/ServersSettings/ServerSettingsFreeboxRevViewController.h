//
//  ServerSettingsFreeboxRevViewController
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2013 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TextCell.h"
#import "UserAccount.h"

#if TARGET_OS_IOS
@interface ServerSettingsFreeboxRevViewController : UITableViewController<UITextFieldDelegate, UIAlertViewDelegate>
#elif TARGET_OS_TV
@interface ServerSettingsFreeboxRevViewController : UITableViewController<UITextFieldDelegate>
#endif
{
    @private
    UserAccount * userAccount;
    NSInteger    accountIndex;
    
    TextCell * textCellProfile;
    TextCell * textCellAddress;
    TextCell * textCellPort;
}

@property(nonatomic, copy) UserAccount * userAccount;
@property(nonatomic, strong) TextCell * textCellProfile;
@property(nonatomic, strong) TextCell * textCellAddress;
@property(nonatomic, strong) TextCell * textCellPort;
@property(nonatomic) NSInteger    accountIndex;

@property(nonatomic, strong) id currentFirstResponder;
#if TARGET_OS_TV
@property(nonatomic, strong) UITextField *invisibleTextField;
#endif

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index;

@end
