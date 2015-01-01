//
//  ServerSettingsMegaViewController
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TextCell.h"
#import "SwitchCell.h"
#import "UserAccount.h"
#import "MEGASdk.h"

@interface ServerSettingsMegaViewController : UITableViewController<UITextFieldDelegate,MEGARequestDelegate>
{
@private
    UserAccount * userAccount;
    NSInteger    accountIndex;
    
    TextCell * textCellProfile;
}
@property(nonatomic, copy) UserAccount * userAccount;
@property(nonatomic, strong) TextCell * textCellProfile;
@property(nonatomic) NSInteger accountIndex;

@property(nonatomic, strong) id currentFirstResponder;

@property(nonatomic, strong) MEGASdk *megaSDK;
@property(nonatomic, strong) NSString *currentToken;
@property(nonatomic, strong) NSString *password;

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index;

@end
