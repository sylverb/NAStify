//
//  TextCell.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface TextCell : UITableViewCell {
	UILabel *label;
	UITextField *textField;
}

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UITextField *textField;

- (void)setCellDataWithLabelString:(NSString *)labelText 
						  withText:(NSString *)text
				   withPlaceHolder:(NSString *)placeHolder
						  isSecure:(BOOL)secure 
				  withKeyboardType:(UIKeyboardType)type
					  withDelegate:(id)delegate
							andTag:(NSInteger)fieldTag;

@end

