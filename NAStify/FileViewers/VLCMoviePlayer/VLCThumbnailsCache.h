/*****************************************************************************
 * VLCThumbnailsCache.h
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013-2014 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Gleb Pinigin <gpinigin # gmail.com>
 *          Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import <Foundation/Foundation.h>

@interface VLCThumbnailsCache : NSObject

#if !(TARGET_IPHONE_SIMULATOR)
+ (UIImage *)thumbnailForMediaFile:(MLFile *)mediaFile;
#endif

+ (UIImage *)thumbnailForMediaItemWithTitle:(NSString *)title Artist:(NSString*)artist andAlbumName:(NSString*)albumname;

#if !(TARGET_IPHONE_SIMULATOR)
+ (UIImage *)thumbnailForShow:(MLShow *)mediaShow;
+ (UIImage *)thumbnailForLabel:(MLLabel *)mediaLabel;
#endif

@end
