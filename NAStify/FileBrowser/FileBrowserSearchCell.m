//
//  FileBrowserSearchCell.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "FileBrowserSearchCell.h"


@implementation FileBrowserSearchCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
	{
#define textXOffset 50
		NSInteger firstLineYOffset = 3;
		NSInteger secondLineYOffset = 32;
		NSInteger firstLineHeight = 26;
		NSInteger secondLineHeight = 14;
		NSInteger firstLineFontSize = 17;
		NSInteger secondLineFontSize = 12;
        
		self.nameLabel = [[UITextField alloc] initWithFrame:CGRectMake(textXOffset,firstLineYOffset,250,firstLineHeight)];
		self.nameLabel.font = [UIFont fontWithName:@"Helvetica" size:firstLineFontSize];
		self.nameLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
		[self addSubview:self.nameLabel];
        self.nameLabel.autocorrectionType = UITextAutocorrectionTypeNo;
		
		self.pathLabel = [[UILabel alloc] initWithFrame:CGRectMake(textXOffset,secondLineYOffset,210,secondLineHeight)];
        self.pathLabel.backgroundColor = [UIColor clearColor];
		self.pathLabel.font = [UIFont systemFontOfSize:secondLineFontSize];
		self.pathLabel.textColor = [UIColor lightGrayColor];
		self.pathLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[self addSubview:self.pathLabel];
		
        self.sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(240,secondLineYOffset,70,secondLineHeight)];
        self.sizeLabel.backgroundColor = [UIColor clearColor];
		self.sizeLabel.font = [UIFont systemFontOfSize:secondLineFontSize];
		self.sizeLabel.textColor = [UIColor lightGrayColor];
		self.sizeLabel.textAlignment = NSTextAlignmentRight;
		self.sizeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self addSubview:self.sizeLabel];
		
		self.fileTypeImage = [[UIImageView alloc] initWithFrame:CGRectMake(3, 3, 44, 44)];
		self.fileTypeImage.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
		[self addSubview:self.fileTypeImage];

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
	self.nameLabel.delegate = delegate;
	self.nameLabel.tag = tag;
	self.nameLabel.enabled = NO;
	self.pathLabel.text = fileItem.shortPath;
	self.sizeLabel.text = fileItem.fileSize;
}

- (void)setEditable
{
	self.nameLabel.enabled = YES;
}

- (void)setUneditable
{
	self.nameLabel.enabled = NO;
}

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
    
    b = self.pathLabel.frame;
	b.origin.x = self.contentView.frame.origin.x + textXOffset;
	[self.pathLabel setFrame:b];
    
    b = self.fileTypeImage.frame;
	b.origin.x = self.contentView.frame.origin.x + 3;
	[self.fileTypeImage setFrame:b];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    [[UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:0.4] setStroke];
    
    CGContextSetLineWidth(context, 1);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 15, 49.5);
    CGContextAddLineToPoint(context, CGRectGetMaxX(rect) - 15, 49.5);
    
    CGContextStrokePath(context);
}

@end
