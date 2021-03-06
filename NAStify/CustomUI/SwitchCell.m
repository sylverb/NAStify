//
//  SwitchCell.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "SwitchCell.h"


@implementation SwitchCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])
	{
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			self.label = [[UILabel alloc] initWithFrame:CGRectMake(20,11,170,21)];
		}
        else
        {
			self.label = [[UILabel alloc] initWithFrame:CGRectMake(15,11,175,21)];
		}
        self.label.backgroundColor = [UIColor clearColor];


		//Set properties
		self.label.adjustsFontSizeToFitWidth = YES;
		self.label.minimumScaleFactor = 10.0/[UIFont labelFontSize];
		self.label.autoresizingMask = UIViewAutoresizingFlexibleWidth;

		[self.contentView addSubview:self.label];

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			self.switchButton = [[UISwitch alloc] initWithFrame:CGRectMake(215,8,0,0)];
		}
        else
        {
            self.switchButton = [[UISwitch alloc] initWithFrame:CGRectMake(250,8,0,0)];
		}

		//Set properties
		self.switchButton.userInteractionEnabled = YES;
		self.switchButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;

		[self.contentView addSubview:self.switchButton];
    }
    return self;
}

- (void)setCellDataWithLabelString:(NSString *)labelText 
						 withState:(BOOL)state
							andTag:(NSInteger)fieldTag
{
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.label.text = labelText;
	[self.switchButton setOn:state animated:NO];
	self.switchButton.tag = fieldTag;
}

@end
