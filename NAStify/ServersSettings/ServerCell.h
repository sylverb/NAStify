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

#if TARGET_OS_IOS
@property(nonatomic, strong) UITextField * serverLabel;
@property(nonatomic, strong) UIImageView * fileTypeImage;
#endif
- (void)setAccount:(UserAccount *)account;
- (void)serverImage:(UIImage *)image;

@end
