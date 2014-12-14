//
//  ServerTypeCell.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServerTypeCell.h"


@implementation ServerTypeCell

- (void)setServerType:(SERVER_TYPE)server
{
    _serverType = server;
    
    // Remove previous image
    if (self.serverTypeImage)
    {
        [self.serverTypeImage removeFromSuperview];
    }
    // Images shall be :
    // iPhone : @1x: 240x40, @2x: 480x80, @3x: 720x120
    // iPad   : @1x: 480x80, @2x: 960x160
    self.serverTypeImage = [[UIImageView alloc] initWithFrame:CGRectMake(40, 9, 240, 40)];
    self.serverTypeImage.autoresizingMask = UIViewAutoresizingNone;
    
    switch (self.serverType)
    {
        case SERVER_TYPE_WEBDAV:
        {
            self.serverTypeImage.image = [UIImage imageNamed:@"webdav.png"];
            break;
        }
        case SERVER_TYPE_FTP:
        case SERVER_TYPE_SFTP:
        {
            self.serverTypeImage.image = [UIImage imageNamed:@"ftp-ftps-sftp.png"];
            break;
        }
        case SERVER_TYPE_SYNOLOGY:
        {
            self.serverTypeImage.image = [UIImage imageNamed:@"synology.png"];
            break;
        }
        case SERVER_TYPE_FREEBOX_REVOLUTION:
        {
            self.serverTypeImage.image = [UIImage imageNamed:@"freebox.png"];
            break;
        }
        case SERVER_TYPE_QNAP:
        {
            self.serverTypeImage.image = [UIImage imageNamed:@"qnap.png"];
            break;
        }
        case SERVER_TYPE_DROPBOX:
        {
            self.serverTypeImage.image = [UIImage imageNamed:@"dropbox.png"];
            break;
        }
        case SERVER_TYPE_SAMBA:
        {
            self.serverTypeImage.image = [UIImage imageNamed:@"samba.png"];
            break;
        }
        case SERVER_TYPE_BOX:
        {
            self.serverTypeImage.image = [UIImage imageNamed:@"box.png"];
            break;
        }
        case SERVER_TYPE_GOOGLEDRIVE:
        {
            self.serverTypeImage.image = [UIImage imageNamed:@"googledrive.png"];
            break;
        }
        default:
            break;
    }
    [self addSubview:self.serverTypeImage];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat width = self.contentView.frame.size.width;
    CGFloat height = self.contentView.frame.size.height;
    CGRect b = self.serverTypeImage.frame;
    b.origin.x = self.contentView.frame.origin.x + width/20;
    b.size.width = self.contentView.frame.size.width - width/10;
    b.origin.y = self.contentView.frame.origin.y + height/10;
    b.size.height = self.contentView.frame.size.height - height/5;
    [self.serverTypeImage setFrame:b];
}

@end
