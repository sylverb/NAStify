//
//  ServerCell.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServerCell.h"


@implementation ServerCell

#if TARGET_OS_IOS
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
        }
        else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        {
            self.serverLabel = [[UITextField alloc] initWithFrame:CGRectMake(textXOffset,firstLineYOffset,260,firstLineHeight)];
        }
        else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomTV)
        {
            firstLineHeight = 64;
            firstLineFontSize = 45;
            self.serverLabel = [[UITextField alloc] initWithFrame:CGRectMake(textXOffset,firstLineYOffset,253,firstLineHeight)];
        }
        
        self.serverLabel.font = [UIFont fontWithName:@"Helvetica" size:firstLineFontSize];
        self.serverLabel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
        self.serverLabel.userInteractionEnabled = NO;
        [self.contentView addSubview:self.serverLabel];
        
        // Images shall be a 90x90 sized square for retina and 45x45 for non retina
        self.fileTypeImage = [[UIImageView alloc] initWithFrame:CGRectMake(5, 3, 45, 45)];
        self.fileTypeImage.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
        [self.contentView addSubview:self.fileTypeImage];
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
#endif

- (void)setAccount:(UserAccount *)account
{
    UIImage *serverImage = nil;
    switch (account.serverType)
    {
        case SERVER_TYPE_WEBDAV:
        {
            serverImage = [UIImage imageNamed:@"webdav_small.png"];
            break;
        }
        case SERVER_TYPE_FTP:
        {
            if (account.boolSSL)
            {
                serverImage = [UIImage imageNamed:@"ftps_small.png"];
            }
            else
            {
                serverImage = [UIImage imageNamed:@"ftp_small.png"];
            }
            break;
        }
        case SERVER_TYPE_SFTP:
        {
            serverImage = [UIImage imageNamed:@"sftp_small.png"];
            break;
        }
        case SERVER_TYPE_SYNOLOGY:
        {
            serverImage = [UIImage imageNamed:@"synology_small.png"];
            break;
        }
        case SERVER_TYPE_FREEBOX_REVOLUTION:
        {
            serverImage = [UIImage imageNamed:@"freebox_small.png"];
            break;
        }
        case SERVER_TYPE_DROPBOX:
        {
            serverImage = [UIImage imageNamed:@"dropbox_small.png"];
            break;
        }
        case SERVER_TYPE_PYDIO:
        {
            serverImage = [UIImage imageNamed:@"pydio_small.png"];
            break;
        }
        case SERVER_TYPE_QNAP:
        {
            serverImage = [UIImage imageNamed:@"qnap_small.png"];
            break;
        }
        case SERVER_TYPE_BOX:
        {
            serverImage = [UIImage imageNamed:@"box_small.png"];
            break;
        }
        case SERVER_TYPE_LOCAL:
        {
            serverImage = [UIImage imageNamed:@"local-storage.png"];
            break;
        }
        case SERVER_TYPE_GOOGLEDRIVE:
        {
            serverImage = [UIImage imageNamed:@"googledrive_small.png"];
            break;
        }
        case SERVER_TYPE_MEGA:
        {
            serverImage = [UIImage imageNamed:@"mega_small.png"];
            break;
        }
        case SERVER_TYPE_ONEDRIVE:
        {
            serverImage = [UIImage imageNamed:@"onedrive_small.png"];
            break;
        }
        case SERVER_TYPE_OWNCLOUD:
        {
            serverImage = [UIImage imageNamed:@"owncloud_small.png"];
            break;
        }
#ifdef SAMBA
        case SERVER_TYPE_SAMBA:
        {
            sserverImage = [UIImage imageNamed:@"samba_small.png"];
            break;
        }
#endif
        default:
        {
            break;
        }
    }
#if TARGET_OS_IOS
    self.fileTypeImage.image = serverImage;
    
    if (([account.accountName isEqualToString:@""]) || (account.accountName == nil))
    {
        self.serverLabel.text = NSLocalizedString(@"Unknown", @"");
    }
    else
    {
        self.serverLabel.text = account.accountName;
    }
#elif TARGET_OS_TV
    self.imageView.image = serverImage;
    
    if (([account.accountName isEqualToString:@""]) || (account.accountName == nil))
    {
        self.textLabel.text = NSLocalizedString(@"Unknown", @"");
    }
    else
    {
        self.textLabel.text = account.accountName;
    }
#endif
}

@end
