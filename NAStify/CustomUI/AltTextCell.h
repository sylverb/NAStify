//
//  AltTextCell.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AltTextCell : UITableViewCell {
	UILabel *label;
	UITextField *textField;
}

@property (nonatomic, retain) UILabel *label;
@property (nonatomic, retain) UITextField *textField;

- (void)setCellDataWithLabelString:(NSString *)labelText
						  withText:(NSString *)text
						  isSecure:(BOOL)secure
				  withKeyboardType:(UIKeyboardType)type
					  withDelegate:(id)delegate
							andTag:(NSInteger)fieldTag;

@end
