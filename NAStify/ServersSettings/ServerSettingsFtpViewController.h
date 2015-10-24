//
//  ServerSettingsFtpViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TextCell.h"
#if TARGET_OS_IOS
#import "SwitchCell.h"
#endif
#import "SegCtrlCell.h"
#if TARGET_OS_IOS
#import "TextViewCell.h"
#endif
#import "UserAccount.h"
#import "TableSelectViewController.h"

@interface ServerSettingsFtpViewController : UITableViewController<UITextFieldDelegate, TableSelectViewControllerDelegate>
{
    @private
    UserAccount * userAccount;
    NSInteger    accountIndex;
    
    TextCell * textCellProfile;
    TextCell * textCellAddress;
    TextCell * textCellPort;
    TextCell * textCellUsername;
    TextCell * textCellPassword;
#if TARGET_OS_IOS
    TextViewCell * textViewCellPrivateCert;
    TextViewCell * textViewCellPublicCert;
#endif
}

@property(nonatomic, copy) UserAccount * userAccount;
@property(nonatomic, strong) TextCell * textCellProfile;
@property(nonatomic, strong) TextCell * textCellAddress;
@property(nonatomic, strong) TextCell * textCellPort;
@property(nonatomic, strong) TextCell * textCellUsername;
@property(nonatomic, strong) TextCell * textCellPassword;
@property(nonatomic, strong) SegCtrlCell *protocolSegCtrlCell;
@property(nonatomic, strong) SegCtrlCell *transfertModeSegCtrlCell;

#if TARGET_OS_IOS
@property(nonatomic, strong) TextViewCell * textViewCellPrivateCert;
@property(nonatomic, strong) TextViewCell * textViewCellPublicCert;
#endif
@property(nonatomic) NSInteger    accountIndex;
@property(nonatomic, strong) NSString *localPassword;
@property(nonatomic, strong) NSString *localPubCert;
@property(nonatomic, strong) NSString *localPrivCert;

@property(nonatomic, strong) NSArray *codingOptions;
@property(nonatomic) NSInteger    codingIndex;
@property(nonatomic, strong) NSArray *curlCoding;

@property(nonatomic, strong) id currentFirstResponder;

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index;
#if TARGET_OS_IOS
- (void)switchValueChanged:(id)sender;
#endif
@end
