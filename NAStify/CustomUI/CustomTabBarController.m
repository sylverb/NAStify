//
//  CustomTabBarController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "CustomTabBarController.h"

@implementation CustomTabBarController

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if ((interfaceOrientation == UIInterfaceOrientationLandscapeLeft) ||
		(interfaceOrientation == UIInterfaceOrientationLandscapeRight) ||
		(interfaceOrientation == UIInterfaceOrientationPortrait))
    {
		return YES;
	}
    else
    {
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            return YES;
        }
        else
        {
            return NO;
        }
	}
}

- (void)setTabBarHidden:(BOOL)hidden withAnimation:(BOOL)animated
{
    if (hidden)
    {
        if (!self.hidden)
        {
            UIView *mainView = [self.view.subviews objectAtIndex:0];
            if (animated)
            {
                [UIView beginAnimations:nil context:nil];
                [UIView setAnimationDelegate:nil];
                [UIView setAnimationDuration:0.2];
            }
            [self.tabBar setAlpha:0.0];
            float height;
            float width;
            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
            {
                height = [UIScreen mainScreen].bounds.size.height;
                width = [UIScreen mainScreen].bounds.size.width;
            }
            else
            {
                width = [UIScreen mainScreen].bounds.size.height;
                height = [UIScreen mainScreen].bounds.size.width;
            }
            mainView.frame = CGRectMake(0,
                                        0,
                                        width,
                                        height );
            
            if (animated)
            {
                [UIView commitAnimations];
            }
            self.hidden = YES;
        }
    }
    else
    {
        if (self.hidden) {
            float height;
            float width;
            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
            {
                width = [UIScreen mainScreen].bounds.size.width;
                height = [UIScreen mainScreen].bounds.size.height;
            }
            else
            {
                width = [UIScreen mainScreen].bounds.size.height;
                height = [UIScreen mainScreen].bounds.size.width;
            }
            
            UIView *mainView = [self.view.subviews objectAtIndex:0];
            if (animated)
            {
                [UIView beginAnimations:nil context:nil];
                [UIView setAnimationDelegate:nil];
                [UIView setAnimationDuration:0.2];
            }
            [self.tabBar setAlpha:1.0];
            mainView.frame = CGRectMake(0,
                                        0,
                                        width,
                                        height - 49);
            if (animated)
            {
                [UIView commitAnimations];
            }
            self.hidden = NO;
        }
    }
}

@end
