//
//  CustomMoviePlayerViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@interface CustomMoviePlayerViewController : MPMoviePlayerViewController 

@property (nonatomic) BOOL allowsAirPlay;

- (void)startPlaying;

@end
