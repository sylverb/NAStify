//
//  CustomMoviePlayerViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2015 CodeIsALie. All rights reserved.
//

#import "TVCustomMoviePlayerViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

@interface CustomMoviePlayerViewController ()

@property (nonatomic, retain) AVPlayerViewController *avPlayerViewcontroller;

@end

@implementation CustomMoviePlayerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    AVPlayerItem* playerItem = [AVPlayerItem playerItemWithURL:self.url];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mediaDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];

    AVPlayerViewController *playerViewController = [[AVPlayerViewController alloc] init];
    playerViewController.player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
    playerViewController.player.allowsExternalPlayback = self.allowsAirPlay;
    playerViewController.view.frame = self.view.frame;
    

    self.avPlayerViewcontroller = playerViewController;
    
    [self.view addSubview:playerViewController.view];
    
    // Start playback
    [self.avPlayerViewcontroller.player play];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.avPlayerViewcontroller.player pause];
    self.avPlayerViewcontroller.player = nil;
}

#pragma mark - Notifications management

-(void)mediaDidFinishPlaying:(NSNotification *) notification
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
