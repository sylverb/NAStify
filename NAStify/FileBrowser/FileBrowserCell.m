//
//  FileBrowserCell.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "FileBrowserCell.h"


@implementation FileBrowserCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
	{
#if TARGET_OS_IOS
#define textXOffset 50
#define CellHeight 50
		NSInteger firstLineYOffset = 3;
		NSInteger secondLineYOffset = 32;
		NSInteger firstLineHeight = 26;
		NSInteger secondLineHeight = 14;
		NSInteger firstLineFontSize = 17;
		NSInteger secondLineFontSize = 12;
        NSInteger cellHeight = 50;
#elif TARGET_OS_TV
#define textXOffset 70
#define CellHeight 80
        NSInteger firstLineYOffset = 3;
        NSInteger secondLineYOffset = 50;
        NSInteger firstLineHeight = 50;
        NSInteger secondLineHeight = 27;
        NSInteger firstLineFontSize = 45;
        NSInteger secondLineFontSize = 23;
#endif
#if TARGET_OS_IOS
		self.nameLabel = [[UITextField alloc] initWithFrame:CGRectMake(textXOffset,firstLineYOffset,250,firstLineHeight)];
        self.nameLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
        self.nameLabel.autocorrectionType = UITextAutocorrectionTypeNo;
#elif TARGET_OS_TV
        self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(textXOffset,firstLineYOffset,1920-100,firstLineHeight)];
        self.nameLabel.textColor = [UIColor blackColor];

#endif
		self.nameLabel.font = [UIFont boldSystemFontOfSize:firstLineFontSize];
		[self.contentView addSubview:self.nameLabel];
		
#if TARGET_OS_IOS
		self.dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(textXOffset,secondLineYOffset,130,secondLineHeight)];
#elif TARGET_OS_TV
        self.dateLabel = [[UILabel alloc] initWithFrame:CGRectMake(textXOffset,secondLineYOffset,300,secondLineHeight)];
#endif
        self.dateLabel.backgroundColor = [UIColor clearColor];
		self.dateLabel.font = [UIFont systemFontOfSize:secondLineFontSize];
		self.dateLabel.textColor = [UIColor lightGrayColor];
		self.dateLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
		[self.contentView addSubview:self.dateLabel];
		
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
			self.ownerLabel = [[UILabel alloc] initWithFrame:CGRectMake(270,secondLineYOffset,200,secondLineHeight)];
            self.ownerLabel.backgroundColor = [UIColor clearColor];
			self.ownerLabel.font = [UIFont systemFontOfSize:secondLineFontSize];
			self.ownerLabel.textColor = [UIColor lightGrayColor];
			self.ownerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			[self.contentView addSubview:self.ownerLabel];
		}
        else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomTV)
        {
            self.ownerLabel = [[UILabel alloc] initWithFrame:CGRectMake(350,secondLineYOffset,200,secondLineHeight)];
            self.ownerLabel.backgroundColor = [UIColor clearColor];
            self.ownerLabel.font = [UIFont systemFontOfSize:secondLineFontSize];
            self.ownerLabel.textColor = [UIColor lightGrayColor];
            [self.contentView addSubview:self.ownerLabel];
        }
        else
        {
			self.ownerLabel = nil;
		}
		
#if TARGET_OS_IOS
        self.sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(240,secondLineYOffset,70,secondLineHeight)];
#elif TARGET_OS_TV
        self.sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(700,secondLineYOffset,130,secondLineHeight)];
#endif
        self.sizeLabel.backgroundColor = [UIColor clearColor];
		self.sizeLabel.font = [UIFont systemFontOfSize:secondLineFontSize];
		self.sizeLabel.textColor = [UIColor lightGrayColor];
#if TARGET_OS_IOS
		self.sizeLabel.textAlignment = NSTextAlignmentRight;
        self.sizeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
#elif TARGET_OS_TV
        self.sizeLabel.textAlignment = NSTextAlignmentLeft;
#endif
		[self.contentView addSubview:self.sizeLabel];
		
#if TARGET_OS_IOS
		self.fileTypeImage = [[UIImageView alloc] initWithFrame:CGRectMake(3, 3, 44, 44)];
		self.fileTypeImage.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
#elif TARGET_OS_TV
        self.fileTypeImage = [[UIImageView alloc] initWithFrame:CGRectMake(3, 8, 64, 64)];
#endif
		[self.contentView addSubview:self.fileTypeImage];

        self.ejectableImage = [[UIImageView alloc] initWithFrame:CGRectMake(18, 22, 15, 15)];
		self.ejectableImage.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
		[self.contentView addSubview:self.ejectableImage];

        self.selectedBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];
        self.selectedBackgroundView.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:0.5];

    }
    return self;
}


- (void)setFileItem:(FileItem *)fileItem withDelegate:(id)delegate andTag:(NSInteger)tag {
    if ([fileItem fileType] == FILETYPE_FOLDER)
    {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    else
    {
        self.accessoryType = UITableViewCellAccessoryNone;
    }
    self.fileTypeImage.image = [fileItem image];
    self.fileTypeImage.alpha = 0.65;
	self.oldName = fileItem.name;
	self.nameLabel.text = fileItem.name;
#if TARGET_OS_IOS
	self.nameLabel.delegate = delegate;
#endif
	self.nameLabel.tag = tag;
	self.nameLabel.enabled = NO;
	self.dateLabel.text = fileItem.fileDate;
	self.sizeLabel.text = fileItem.fileSize;
	if ((fileItem.owner) && (![fileItem.owner isEqualToString:@""]))
    {
		self.ownerLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Owner: %@",nil), fileItem.owner];
    }
    else
    {
        self.ownerLabel.text = nil;
    }
    if (fileItem.isEjectable)
    {
        self.ejectableImage.image = [UIImage imageNamed:@"eject.png"];
    }
    else
    {
        self.ejectableImage.image = nil;
    }
}

- (void)setEditable
{
	self.nameLabel.enabled = YES;
}

- (void)setUneditable
{
	self.nameLabel.enabled = NO;
}

#if TARGET_OS_IOS
- (void)layoutSubviews
{
    [super layoutSubviews];
    
	// nameLabel and sizeLabel are following the contentView bounds to adapt the frame when the delete button appears
	CGRect b = self.nameLabel.frame;
	b.size.width = self.contentView.frame.size.width - 50;
	b.origin.x = self.contentView.frame.origin.x + textXOffset;
	[self.nameLabel setFrame:b];
    
    b = self.sizeLabel.frame;
    b.origin.x = self.contentView.frame.origin.x + self.contentView.frame.size.width - 80;
    [self.sizeLabel setFrame:b];
    
    b = self.dateLabel.frame;
	b.origin.x = self.contentView.frame.origin.x + textXOffset;
	[self.dateLabel setFrame:b];
    
    b = self.fileTypeImage.frame;
	b.origin.x = self.contentView.frame.origin.x + 3;
	[self.fileTypeImage setFrame:b];
    
    b = self.ejectableImage.frame;
	b.origin.x = self.contentView.frame.origin.x + 18;
	[self.ejectableImage setFrame:b];
}
#endif

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    [[UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:0.4] setStroke];
    
    CGContextSetLineWidth(context, 1);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 15, CellHeight - .5);
    CGContextAddLineToPoint(context, CGRectGetMaxX(rect) - 15, CellHeight - .5);
    CGContextStrokePath(context);
}

@end
