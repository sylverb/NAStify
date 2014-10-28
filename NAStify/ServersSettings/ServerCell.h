//
//  ServerCell.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UserAccount.h"

@interface ServerCell : UITableViewCell

@property(nonatomic, strong) UITextField * serverLabel;
@property(nonatomic, strong) UIImageView * fileTypeImage;

- (void)setAccount:(UserAccount *)account;

@end
