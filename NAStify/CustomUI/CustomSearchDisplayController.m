//
//  CustomSearchDisplayController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "CustomSearchDisplayController.h"

@implementation CustomSearchDisplayController

- (void)setActive:(BOOL)visible animated:(BOOL)animated;
{
    [super setActive:visible animated:animated];
    
    if (visible)
    {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        {
            [self.searchContentsController.navigationController setNavigationBarHidden:NO animated:NO];
        }
        else
        {
            CGRect bounds = self.searchContentsController.view.bounds;
            bounds.origin.y = -self.searchContentsController.navigationController.navigationBar.bounds.size.height;
            [self.searchContentsController.view setBounds:bounds];
            [self.searchContentsController.navigationController setNavigationBarHidden:NO animated:NO];
        }
    }
    else
    {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            CGRect bounds = self.searchContentsController.view.bounds;
            bounds.origin.y = 0;
            [self.searchContentsController.view setBounds:bounds];
//            [self.searchContentsController.navigationController setNavigationBarHidden:NO animated:NO];
        }
    }
}
@end
