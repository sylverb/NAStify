//
//  AltTextCell.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "AltTextCell.h"


@implementation AltTextCell

@synthesize label;
@synthesize textField;


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])
	{
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			self.label = [[UILabel alloc] initWithFrame:CGRectMake(55,11,157,21)];
		}
        else
        {
			self.label = [[UILabel alloc] initWithFrame:CGRectMake(20,11,157,21)];
		}
        
        self.label.backgroundColor = [UIColor clearColor];
		self.label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin ;
        
		[self addSubview:label];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			self.textField = [[UITextField alloc] initWithFrame:CGRectMake(185,1,80,43)];
		}
        else
        {
			self.textField = [[UITextField alloc] initWithFrame:CGRectMake(185,1,98,43)];
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
		self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		
		[self addSubview:textField];
    }
    return self;
}

- (void)setCellDataWithLabelString:(NSString *)labelText withText:(NSString *)fieldText isSecure:(BOOL)secure withKeyboardType:(UIKeyboardType)type withDelegate:(id)delegate andTag:(NSInteger)fieldTag{
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.label.text = labelText;
	self.textField.text = fieldText;
	[self.textField setSecureTextEntry:secure];
	[self.textField setKeyboardType:type];
	self.textField.delegate = delegate;
	self.textField.tag = fieldTag;
}

- (BOOL)resignFirstResponder {
	[self.textField resignFirstResponder];
	return [super resignFirstResponder];
}

@end
