//
//  TextViewCell.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface TextViewCell : UITableViewCell

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UITextView *textView;

- (void)setCellDataWithLabelString:(NSString *)labelText 
						  withText:(NSString *)text
				  withKeyboardType:(UIKeyboardType)type
					  withDelegate:(id)delegate
							andTag:(NSInteger)fieldTag;

@end

