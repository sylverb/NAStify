//
//  ALAssetsGroupAdditions.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "ALAssetsGroupAdditions.h"

@implementation ALAssetsGroup (ALAssetsGroupAdditions)

- (NSInteger *)numberOfPhotoAssets:(BOOL)countPhoto andVideoAssets:(BOOL)countVideo
{
    __block NSInteger count = 0;
    
    // Asset enumerator Block
    void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *result, NSUInteger index, BOOL *stop)
    {
        if(result != nil)
        {
            NSString *type = [result valueForProperty:@"ALAssetPropertyType"];
            if (((type == ALAssetTypePhoto) && (countPhoto)) ||
                ((type == ALAssetTypeVideo) && (countVideo)))
            {
                count++;
            }
        }
    };

    [self enumerateAssetsUsingBlock:assetEnumerator];
    return count;
}

@end
