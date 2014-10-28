//
//  CustomNavigationController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "CustomNavigationController.h"

@implementation CustomNavigationController

// Overwrite disablesAutomaticKeyboardDismissal to allow to disable the keyboard when modalPresentationStyle = UIModalPresentationFormSheet
- (BOOL)disablesAutomaticKeyboardDismissal
{
    return NO;
}

@end