//
//  ALAssetsGroupAdditions.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface ALAssetsGroup (ALAssetsGroupAdditions)

/*
 * return number of photo and video assets in group
 */
- (NSInteger *)numberOfPhotoAssets:(BOOL)countPhoto andVideoAssets:(BOOL)countVideo;

@end
