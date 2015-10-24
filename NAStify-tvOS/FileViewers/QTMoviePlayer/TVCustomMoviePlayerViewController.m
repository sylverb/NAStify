//
//  CustomMoviePlayerViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "TVCustomMoviePlayerViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

@interface CustomMoviePlayerViewController ()

@property (nonatomic, retain) AVPlayerViewController *avPlayerViewcontroller;

@end

@implementation CustomMoviePlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    AVPlayerViewController *playerViewController = [[AVPlayerViewController alloc] init];
    playerViewController.player = [AVPlayer playerWithURL:self.url];
    playerViewController.view.frame = self.view.frame;
    
    self.avPlayerViewcontroller = playerViewController;
    
    [self.view addSubview:playerViewController.view];
    
    // Start playback
    [self.avPlayerViewcontroller.player play];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
