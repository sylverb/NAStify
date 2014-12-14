//
//  ServerSettingsGoogleDriveViewController
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GTMOAuth2ViewControllerTouch.h"
#import "TextCell.h"
#import "SwitchCell.h"
#import "UserAccount.h"

@interface ServerSettingsGoogleDriveViewController : UITableViewController<UITextFieldDelegate>
{
    @private
    UserAccount * userAccount;
    NSInteger    accountIndex;
    
    TextCell * textCellProfile;
}

@property(nonatomic, copy) UserAccount * userAccount;
@property(nonatomic, strong) TextCell * textCellProfile;
@property(nonatomic) NSInteger    accountIndex;

@property(nonatomic, strong) id currentFirstResponder;

@property(nonatomic) BOOL isAuthorized;
@property(nonatomic, strong) GTMOAuth2Authentication *currentAuth;

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index;

@end
