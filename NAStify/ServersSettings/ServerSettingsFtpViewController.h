//
//  ServerSettingsFtpViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TextCell.h"
#import "SwitchCell.h"
#import "SegCtrlCell.h"
#import "TextViewCell.h"
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
    TextViewCell * textViewCellPrivateCert;
    TextViewCell * textViewCellPublicCert;
}

@property(nonatomic, copy) UserAccount * userAccount;
@property(nonatomic, strong) TextCell * textCellProfile;
@property(nonatomic, strong) TextCell * textCellAddress;
@property(nonatomic, strong) TextCell * textCellPort;
@property(nonatomic, strong) TextCell * textCellUsername;
@property(nonatomic, strong) TextCell * textCellPassword;
@property(nonatomic, strong) TextViewCell * textViewCellPrivateCert;
@property(nonatomic, strong) TextViewCell * textViewCellPublicCert;
@property(nonatomic) NSInteger    accountIndex;
@property(nonatomic, strong) NSString *localPassword;
@property(nonatomic, strong) NSString *localPubCert;
@property(nonatomic, strong) NSString *localPrivCert;

@property(nonatomic, strong) NSArray *codingOptions;
@property(nonatomic) NSInteger    codingIndex;
@property(nonatomic, strong) NSArray *curlCoding;

@property(nonatomic, strong) id currentFirstResponder;

- (id)initWithStyle:(UITableViewStyle)style andAccount:(UserAccount *)account andIndex:(NSInteger)index;
- (void)switchValueChanged:(id)sender;

@end
