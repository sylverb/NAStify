//
//  CustomMoviePlayerViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "CustomMoviePlayerViewController.h"

@implementation CustomMoviePlayerViewController

- (void) moviePlayerLoadStateChanged:(NSNotification*)notification 
{
	// Unless state is unknown, start playback
	if ([self.moviePlayer loadState] != MPMovieLoadStateUnknown)
    {
		// Remove observer
		[[NSNotificationCenter 	defaultCenter] removeObserver:self
                                                         name:MPMoviePlayerLoadStateDidChangeNotification
                                                       object:notification.object];
		
		// Play the movie
		[self.moviePlayer play];
	}
}

- (void) moviePlayBackDidFinish:(NSNotification*)notification 
{
    // Obtain the reason why the movie playback finished
    NSNumber *finishReason = [[notification userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];    
    // Dismiss the view controller ONLY when the reason is not "playback ended"
    
    if ([finishReason intValue] != MPMovieFinishReasonPlaybackEnded)
    {     
        MPMoviePlayerController *moviePlayer = [notification object];     
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:MPMoviePlayerPlaybackDidFinishNotification
                                                      object:moviePlayer];        
        [moviePlayer pause];
        [moviePlayer stop];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void) startPlaying
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    NSError *setCategoryError = nil;
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&setCategoryError];
    
    NSError *activationError = nil;
    [audioSession setActive:YES error:&activationError];
    
    // Set movie player layout
    if (self.allowsAirPlay)
    {
        self.moviePlayer.allowsAirPlay = YES;
    }
    else
    {
        self.moviePlayer.allowsAirPlay = NO;
    }
    
    [self.moviePlayer setFullscreen:YES animated:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayerLoadStateChanged:)
                                                 name:MPMoviePlayerLoadStateDidChangeNotification
                                               object:self.moviePlayer];
    
	// Register to receive a notification when the movie has finished playing.
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:self.moviePlayer];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
    {
		return YES;
    }
	else
    {
		return NO;
    }
}

@end
