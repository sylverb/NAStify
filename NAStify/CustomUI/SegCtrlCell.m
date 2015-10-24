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
        else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        {
			self.label = [[UILabel alloc] initWithFrame:CGRectMake(15,11,175,21)];
		}
        else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomTV)
        {
            self.label = [[UILabel alloc] initWithFrame:CGRectMake(20,1,175,64)];
        }
        
        //Set properties
        self.label.backgroundColor = [UIColor clearColor];
		self.label.adjustsFontSizeToFitWidth = YES;
#if TARGET_OS_IOS
		self.label.minimumFontSize = 10;
#elif TARGET_OS_TV
        self.label.font = [UIFont systemFontOfSize:30.0];
#endif
		self.label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		[self.contentView addSubview:label];
		
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
        else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        {
			self.segmentedControl.frame = CGRectMake(125,5,180,35);
		}
        else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomTV)
        {
            self.segmentedControl.frame = CGRectMake(90,1,180,64);
        }
		
		//Set properties
		self.segmentedControl.userInteractionEnabled = YES;
		self.segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		self.segmentedControl.selectedSegmentIndex = 1;
		
		[self.contentView addSubview:segmentedControl];
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

#if TARGET_OS_TV
- (BOOL)canBecomeFocused
{
    return YES;
}
#endif

@end
