//
//  SegCtrlCell.m
//  Synology DS
//
//  Created by Sylver Bruneau on 14/10/10.
//  Copyright 2010 Sylver Bruneau. All rights reserved.
//

#import "SegCtrlCell.h"


@implementation SegCtrlCell

@synthesize label;
@synthesize segmentedControl;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier withItems:(NSArray *)items
{
    if(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])
	{
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			self.label = [[UILabel alloc] initWithFrame:CGRectMake(20,11,175,21)];
		}
        else
        {
			self.label = [[UILabel alloc] initWithFrame:CGRectMake(15,11,175,21)];
		}
        self.label.backgroundColor = [UIColor clearColor];
		
		//Set properties
		self.label.adjustsFontSizeToFitWidth = YES;
		self.label.minimumFontSize = 10;
		self.label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		[self addSubview:label];
		
        if (items)
        {
            self.segmentedControl = [[UISegmentedControl alloc] initWithItems:items];
        }
        else
        {
            self.segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects: @"Asc.", @"Desc.", nil]];
        }
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			self.segmentedControl.frame = CGRectMake(90,5,180,35);
		}
        else
        {
			self.segmentedControl.frame = CGRectMake(125,5,180,35);
		}
		
		//Set properties
		self.segmentedControl.userInteractionEnabled = YES;
		self.segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		self.segmentedControl.selectedSegmentIndex = 1;
		
		[self addSubview:segmentedControl];
    }
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithStyle:style reuseIdentifier:reuseIdentifier withItems:nil];
}

- (void)setCellDataWithLabelString:(NSString *)labelText 
						 withSelectedIndex:(NSInteger)idx
							andTag:(NSInteger)fieldTag
{
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.label.text = labelText;
	self.segmentedControl.selectedSegmentIndex = idx;
	self.segmentedControl.tag = fieldTag;
}

@end
