/*****************************************************************************
 * VLCSlider.m
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2013 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCSlider.h"

@implementation VLCOBSlider

- (void)awakeFromNib
{
    [self setThumbImage:[UIImage imageNamed:@"modernSliderKnob"] forState:UIControlStateNormal];
}

- (CGRect)trackRectForBounds:(CGRect)bounds
{
    return [super trackRectForBounds:bounds];
}

@end


@implementation VLCSlider

- (void)awakeFromNib
{
    [self setThumbImage:[UIImage imageNamed:@"modernSliderKnob"] forState:UIControlStateNormal];
}

- (CGRect)trackRectForBounds:(CGRect)bounds
{
    return [super trackRectForBounds:bounds];
}

@end
