//
//  TextButtonCell.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "TextButtonCell.h"


@implementation TextButtonCell

@synthesize label;
@synthesize textButton;


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
	{
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            label = [[UILabel alloc] initWithFrame:CGRectMake(20,11,157,21)];
		}
        else
        {
			label = [[UILabel alloc] initWithFrame:CGRectMake(20,11,157,21)];
		}
        label.backgroundColor = [UIColor clearColor];
		label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin ;
		
		[self.contentView addSubview:label];
		
		textButton = [UIButton buttonWithType:UIButtonTypeCustom];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			textButton.frame = CGRectMake(200,1,67,43);
        }
		else
        {
			textButton.frame = CGRectMake(185,1,98,43);
        }
		textButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
		textButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [textButton.titleLabel setFont:[UIFont systemFontOfSize:19]];
        UIColor *textFieldColor = [[UIColor alloc] initWithRed:96.0/255 green:140.0/255 blue:189.0/255 alpha:1.0];
        [textButton setTitleColor:textFieldColor forState:UIControlStateNormal];
        [textButton setTitleColor:textFieldColor forState:UIControlStateSelected];
		[self.contentView addSubview:textButton];
    }
    return self;
}

- (void)setCellDataWithLabelString:(NSString *)labelText withText:(NSString *)fieldText andTag:(NSInteger)fieldTag {
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	label.text = labelText;
	
	[textButton setTitle:fieldText forState:UIControlStateNormal];
	[textButton setTitle:fieldText forState:UIControlStateSelected];
	textButton.tag = fieldTag;
}
@end
