//
//  TextButtonCell.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface TextButtonCell : UITableViewCell {
	UILabel *label;
	UIButton *textButton;
}

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIButton *textButton;

- (void)setCellDataWithLabelString:(NSString *)labelText withText:(NSString *)fieldText andTag:(NSInteger)fieldTag;

@end
