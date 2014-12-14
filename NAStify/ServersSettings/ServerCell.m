//
//  ServerCell.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServerCell.h"


@implementation ServerCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        NSInteger textXOffset = 30;
        NSInteger firstLineYOffset = 6;
        NSInteger firstLineHeight = 39;
        NSInteger firstLineFontSize = 17;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            firstLineFontSize = 25;
            self.serverLabel = [[UITextField alloc] initWithFrame:CGRectMake(textXOffset,firstLineYOffset,253,firstLineHeight)];
        } else {
            self.serverLabel = [[UITextField alloc] initWithFrame:CGRectMake(textXOffset,firstLineYOffset,260,firstLineHeight)];
        }
        
        self.serverLabel.font = [UIFont fontWithName:@"Helvetica" size:firstLineFontSize];
        self.serverLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
        self.serverLabel.userInteractionEnabled = NO;
        [self addSubview:self.serverLabel];
        
        // Images shall be a 90x90 sized square for retina and 45x45 for non retina
        self.fileTypeImage = [[UIImageView alloc] initWithFrame:CGRectMake(5, 3, 45, 45)];
        self.fileTypeImage.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        [self addSubview:self.fileTypeImage];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect b = self.serverLabel.frame;
    b.origin.x = self.contentView.frame.origin.x + 70;
    b.size.width = self.contentView.frame.size.width - 80;
    [self.serverLabel setFrame:b];
    
    // Image
    b = self.fileTypeImage.frame;
    b.origin.x = self.contentView.frame.origin.x + 5;
    [self.fileTypeImage setFrame:b];
}

- (void)setAccount:(UserAccount *)account
{
    switch (account.serverType)
    {
        case SERVER_TYPE_WEBDAV:
        {
            self.fileTypeImage.image = [UIImage imageNamed:@"webdav_small.png"];
            break;
        }
        case SERVER_TYPE_FTP:
        {
            if (account.boolSSL)
            {
                self.fileTypeImage.image = [UIImage imageNamed:@"ftps_small.png"];
            }
            else
            {
                self.fileTypeImage.image = [UIImage imageNamed:@"ftp_small.png"];
            }
            break;
        }
        case SERVER_TYPE_SFTP:
        {
            self.fileTypeImage.image = [UIImage imageNamed:@"sftp_small.png"];
            break;
        }
        case SERVER_TYPE_SYNOLOGY:
        {
            self.fileTypeImage.image = [UIImage imageNamed:@"synology_small.png"];
            break;
        }
        case SERVER_TYPE_FREEBOX_REVOLUTION:
        {
            self.fileTypeImage.image = [UIImage imageNamed:@"freebox_small.png"];
            break;
        }
        case SERVER_TYPE_DROPBOX:
        {
            self.fileTypeImage.image = [UIImage imageNamed:@"dropbox_small.png"];
            break;
        }
        case SERVER_TYPE_QNAP:
        {
            self.fileTypeImage.image = [UIImage imageNamed:@"qnap_small.png"];
            break;
        }
        case SERVER_TYPE_BOX:
        {
            self.fileTypeImage.image = [UIImage imageNamed:@"box_small.png"];
            break;
        }
        case SERVER_TYPE_LOCAL:
        {
            self.fileTypeImage.image = [UIImage imageNamed:@"local-storage.png"];
            break;
        }
        case SERVER_TYPE_GOOGLEDRIVE:
        {
            self.fileTypeImage.image = [UIImage imageNamed:@"googledrive_small.png"];
            break;
        }
        default:
        {
            self.fileTypeImage.image = nil;
            break;
        }
    }
    if (([account.accountName isEqualToString:@""]) || (account.accountName == nil))
    {
        self.serverLabel.text = NSLocalizedString(@"Unknown", @"");
    }
    else
    {
        self.serverLabel.text = account.accountName;
    }
}

@end
