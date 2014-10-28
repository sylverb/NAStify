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
    if (serverTypeImage)
    {
        [serverTypeImage removeFromSuperview];
    }
    // Images shall be a 480x80 sized rectangle for retina and 240x40 for non retina
    serverTypeImage = [[UIImageView alloc] initWithFrame:CGRectMake(40, 9, 240, 40)];
    serverTypeImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    switch (self.serverType)
    {
        case SERVER_TYPE_WEBDAV:
        {
            serverTypeImage.image = [UIImage imageNamed:@"webdav.png"];
            break;
        }
        case SERVER_TYPE_FTP:
        case SERVER_TYPE_SFTP:
        {
            serverTypeImage.image = [UIImage imageNamed:@"ftp-ftps-sftp.png"];
            break;
        }
        case SERVER_TYPE_SYNOLOGY:
        {
            serverTypeImage.image = [UIImage imageNamed:@"synology.png"];
            break;
        }
        case SERVER_TYPE_FREEBOX_REVOLUTION:
        {
            serverTypeImage.image = [UIImage imageNamed:@"freebox.png"];
            break;
        }
        case SERVER_TYPE_QNAP:
        {
            serverTypeImage.image = [UIImage imageNamed:@"qnap.png"];
            break;
        }
        case SERVER_TYPE_DROPBOX:
        {
            serverTypeImage.image = [UIImage imageNamed:@"dropbox.png"];
            break;
        }
        case SERVER_TYPE_SAMBA:
        {
            serverTypeImage.image = [UIImage imageNamed:@"samba.png"];
            break;
        }
        case SERVER_TYPE_BOX:
        {
            serverTypeImage.image = [UIImage imageNamed:@"box.png"];
            break;
        }
        default:
            break;
    }
    [self addSubview:serverTypeImage];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat width = self.contentView.frame.size.width;
    CGFloat height = self.contentView.frame.size.height;
    CGRect b = serverTypeImage.frame;
    b.origin.x = self.contentView.frame.origin.x + width/20;
    b.size.width = self.contentView.frame.size.width - width/10;
    b.origin.y = self.contentView.frame.origin.y + height/10;
    b.size.height = self.contentView.frame.size.height - height/5;
    [serverTypeImage setFrame:b];
}

@end
