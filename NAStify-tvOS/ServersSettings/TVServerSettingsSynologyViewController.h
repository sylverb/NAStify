//
//  TVServerSettingsSynologyViewController.h
//  NAStify
//
//  Created by Sylver B on 22/10/15.
//  Copyright © 2015 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UserAccount.h"

@interface TVServerSettingsSynologyViewController : UIViewController <UITextFieldDelegate>
@property(nonatomic, copy) UserAccount * userAccount;
@property(nonatomic) NSInteger    accountIndex;
@property(nonatomic, strong) NSString *localPassword;

@property(nonatomic, strong) IBOutlet UITextField *textCellProfile;
@property(nonatomic, strong) IBOutlet UITextField *textCellAddress;
@property(nonatomic, strong) IBOutlet UITextField *textCellPort;
@property(nonatomic, strong) IBOutlet UITextField *textCellUsername;
@property(nonatomic, strong) IBOutlet UITextField *textCellPassword;
@property(nonatomic, strong) IBOutlet UIButton *ButtonAdd;

@property(nonatomic, strong) id currentFirstResponder;

- (id)initWithAccount:(UserAccount *)account andIndex:(NSInteger)index;
- (IBAction)addButtonPressed;
@end
