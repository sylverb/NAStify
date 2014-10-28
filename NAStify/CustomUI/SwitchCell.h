//
//  SwitchCell.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface SwitchCell : UITableViewCell

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UISwitch *switchButton;

- (void)setCellDataWithLabelString:(NSString *)labelText 
						 withState:(BOOL)state
							andTag:(NSInteger)fieldTag;

@end
