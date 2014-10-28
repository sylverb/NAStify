//
//  CustomTabBarController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CustomTabBarController : UITabBarController <UITabBarDelegate>

@property (nonatomic) BOOL hidden;

- (void)setTabBarHidden:(BOOL)hidden withAnimation:(BOOL)animated;

@end
