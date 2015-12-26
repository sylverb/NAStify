//
//  ServerCell.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ServerCell.h"

@implementation ServerCell

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
        case SERVER_TYPE_SAMBA:
        {
            serverImage = [UIImage imageNamed:@"samba_small.png"];
            break;
        }
        default:
        {
            break;
        }
    }

    self.imageView.image = serverImage;

    if (([account.accountName isEqualToString:@""]) || (account.accountName == nil))
    {
        self.textLabel.text = NSLocalizedString(@"Unknown", nil);
    }
    else
    {
        self.textLabel.text = account.accountName;
    }
}

- (UIImage *)imageWithImage:(UIImage *)sourceImage scaledToWidth:(float)i_width
{
    float oldWidth = sourceImage.size.width;
    float scaleFactor = i_width / oldWidth;
    
    float newHeight = sourceImage.size.height * scaleFactor;
    float newWidth = oldWidth * scaleFactor;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(newWidth, newHeight), NO, 0);
    [sourceImage drawInRect:CGRectMake(0, 0, newWidth, newHeight)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (void)serverImage:(UIImage *)image
{
#if TARGET_OS_IOS
    self.imageView.image = [self imageWithImage:image scaledToWidth:45.0];
#elif TARGET_OS_TV
    self.imageView.image = [self imageWithImage:image scaledToWidth:64.0];
#endif
}

@end
