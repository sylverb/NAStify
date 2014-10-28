//
//  TextCell.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "TextCell.h"

@implementation TextCell

@synthesize label;
@synthesize textField;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])
	{
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			self.label = [[UILabel alloc] initWithFrame:CGRectMake(55,11,112,21)];
		}
        else
        {
			self.label = [[UILabel alloc] initWithFrame:CGRectMake(15,11,140,21)];
		}
        self.label.backgroundColor = [UIColor clearColor];
		self.label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin ;

		[self addSubview:self.label];

        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			self.textField = [[UITextField alloc] initWithFrame:CGRectMake(60,1,205,43)];
		}
        else
        {
			self.textField = [[UITextField alloc] initWithFrame:CGRectMake(160,1,125,43)];
		}
		//Set properties
		self.textField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
		self.textField.textAlignment = NSTextAlignmentRight;
		UIColor *textFieldColor = [[UIColor alloc] initWithRed:96.0/255 green:140.0/255 blue:189.0/255 alpha:1.0];
		self.textField.textColor = textFieldColor;
		self.textField.borderStyle = UITextBorderStyleNone;
		self.textField.font = [UIFont systemFontOfSize:17.0];
		self.textField.minimumFontSize = 20;
		self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
		self.textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		self.textField.clearsOnBeginEditing = NO;
		self.textField.clearButtonMode = UITextFieldViewModeWhileEditing;
		self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		
		[self addSubview:self.textField];
    }
    return self;
}

- (void)setCellDataWithLabelString:(NSString *)labelText withText:(NSString *)fieldText withPlaceHolder:(NSString *)placeHolder isSecure:(BOOL)secure withKeyboardType:(UIKeyboardType)type withDelegate:(id)delegate andTag:(NSInteger)fieldTag
{
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.label.text = labelText;
	self.textField.text = fieldText;
	self.textField.placeholder = placeHolder;
	[self.textField setSecureTextEntry:secure];
	[self.textField setKeyboardType:type];
    self.textField.returnKeyType = UIReturnKeyNext;
	self.textField.delegate = delegate;
	self.textField.tag = fieldTag;
}

- (BOOL)resignFirstResponder {
	[self.textField resignFirstResponder];
	return [super resignFirstResponder];	
}

@end

