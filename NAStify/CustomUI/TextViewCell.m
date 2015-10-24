//
//  TextViewCell.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "TextViewCell.h"


@implementation TextViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])
	{
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			self.label = [[UILabel alloc] initWithFrame:CGRectMake(20,11,112,21)];
		}
        else
        {
			self.label = [[UILabel alloc] initWithFrame:CGRectMake(10,5,300,21)];
		}
        self.label.backgroundColor = [UIColor clearColor];
        self.label.textAlignment = NSTextAlignmentCenter;
		self.label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin ;

		[self.contentView addSubview:self.label];

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			self.textView = [[UITextView alloc] initWithFrame:CGRectMake(60,1,205,43)];
		}
        else
        {
			self.textView = [[UITextView alloc] initWithFrame:CGRectMake(10,26,300,43)];
		}
		//Set properties
		self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
//		self.textView.textAlignment = NSTextAlignmentRight;
		UIColor *textFieldColor = [[UIColor alloc] initWithRed:96.0/255 green:140.0/255 blue:189.0/255 alpha:1.0];
		self.textView.textColor = textFieldColor;
//		self.textView.borderStyle = UITextBorderStyleNone;
		self.textView.font = [UIFont systemFontOfSize:12.0];
//		self.textView.minimumFontSize = 20;
		self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
//		self.textView.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
//		self.textView.clearsOnBeginEditing = NO;
//		self.textView.clearButtonMode = UITextFieldViewModeWhileEditing;
		self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
		
		[self.contentView addSubview:self.textView];
    }
    return self;
}

- (void)setCellDataWithLabelString:(NSString *)labelText withText:(NSString *)fieldText withKeyboardType:(UIKeyboardType)type withDelegate:(id)delegate andTag:(NSInteger)fieldTag
{
//	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.label.text = labelText;
	self.textView.text = fieldText;
	[self.textView setKeyboardType:type];
    self.textView.returnKeyType = UIReturnKeyNext;
	self.textView.delegate = delegate;
	self.textView.tag = fieldTag;
    
    // Set width to fit text
    CGSize textViewSize = [self.textView sizeThatFits:CGSizeMake(self.textView.frame.size.width, FLT_MAX)];
    CGRect frame = self.textView.frame;
    if (textViewSize.height + self.label.frame.size.height >= 69.0f)
    {
        frame.size.height = textViewSize.height + self.label.frame.size.height;
    }
    else
    {
        frame.size.height = 69.0f;

    }
    [self.textView setFrame:frame];
}

- (BOOL)resignFirstResponder
{
	[self.textView resignFirstResponder];
	return [super resignFirstResponder];	
}

@end

