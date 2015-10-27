/*****************************************************************************
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2015 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCFullscreenMovieTVViewController.h"
#import "VLCPlayerDisplayController.h"
#import "SettingsViewController.h"
#import "VLCFrostedGlasView.h"
#import "VLCTrackSelectorTableViewCell.h"
#import "VLCTrackSelectorHeaderView.h"

#define TRACK_SELECTOR_TABLEVIEW_CELL @"track selector table view cell"
#define TRACK_SELECTOR_TABLEVIEW_SECTIONHEADER @"track selector table view section header"

@interface VLCFullscreenMovieTVViewController ()
{
    BOOL _controlsHidden;
    
    NSTimer *_idleTimer;
    BOOL _playerIsSetup;
    BOOL _viewAppeared;
    
    UISwipeGestureRecognizer *_swipeRecognizerDown;
    UISwipeGestureRecognizer *_swipeRecognizerLeft;
    UISwipeGestureRecognizer *_swipeRecognizerRight;
    UITapGestureRecognizer *_touchRecognizer;
    UITapGestureRecognizer *_playRecognizer;
}
@end

@implementation VLCFullscreenMovieTVViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_swipeRecognizerDown)
        [self.view removeGestureRecognizer:_swipeRecognizerDown];
    if (_swipeRecognizerLeft)
        [self.view removeGestureRecognizer:_swipeRecognizerLeft];
    if (_swipeRecognizerRight)
        [self.view removeGestureRecognizer:_swipeRecognizerRight];
    if (_touchRecognizer)
        [self.view removeGestureRecognizer:_touchRecognizer];
    if (_playRecognizer)
        [self.view removeGestureRecognizer:_playRecognizer];

    _swipeRecognizerDown = nil;
    _swipeRecognizerLeft = nil;
    _swipeRecognizerRight = nil;
    _touchRecognizer = nil;
    _playRecognizer = nil;
}


- (void)viewDidLoad {
    [super viewDidLoad];

    self.extendedLayoutIncludesOpaqueBars = YES;
    self.edgesForExtendedLayout = UIRectEdgeAll;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(appBecameActive:)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(playbackDidStop:)
                   name:VLCPlaybackControllerPlaybackDidStop
                 object:nil];

    _movieView.userInteractionEnabled = NO;
    _playerIsSetup = NO;

    self.titleLabel.text = self.remainingTimeLabel.text = self.playedTimeLabel.text = @"";
    self.playbackProgressView.progress = .0;
    self.bottomOverlayView.hidden = YES;
    
    // Register gestures
    _swipeRecognizerDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                 action:@selector(swipe:)];
    _swipeRecognizerDown.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:_swipeRecognizerDown];
    
    _swipeRecognizerLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                     action:@selector(swipe:)];
    _swipeRecognizerLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:_swipeRecognizerLeft];
    
    _swipeRecognizerRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                     action:@selector(swipe:)];
    _swipeRecognizerRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:_swipeRecognizerRight];
    
    _playRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                              action:@selector(playPause:)];
    [_playRecognizer setAllowedPressTypes:@[@(UIPressTypePlayPause)]];
    [self.view addGestureRecognizer:_playRecognizer];
    
    _touchRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                               action:@selector(touch:)];
    [_touchRecognizer setAllowedPressTypes:@[]];
    [_touchRecognizer setAllowedTouchTypes:@[@(UITouchTypeDirect), @(UITouchTypeIndirect)]];
    [self.view addGestureRecognizer:_touchRecognizer];
    
    // Setting Settings menu
    SettingsViewController *settingsViewController = [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *settingsNavController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    settingsNavController.title = NSLocalizedString(@"Settings",nil);
}

#pragma mark - view events

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.navigationController setNavigationBarHidden:YES animated:animated];

    [self setControlsHidden:NO animated:animated];

    VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
    vpc.delegate = self;
    [vpc recoverPlaybackState];
    
    [self.view setNeedsFocusUpdate];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _viewAppeared = YES;

    VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
    [vpc recoverDisplayedMetadata];
    vpc.videoOutputView = nil;
    vpc.videoOutputView = self.movieView;

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self _resetIdleTimer];
}

- (void)viewWillDisappear:(BOOL)animated
{
    VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
    if (vpc.videoOutputView == self.movieView) {
        vpc.videoOutputView = nil;
    }

    _viewAppeared = NO;
    [self.navigationController setNavigationBarHidden:NO animated:YES];

    [super viewWillDisappear:animated];

    [[UIApplication sharedApplication] sendAction:@selector(closeFullscreenPlayback) to:nil from:self forEvent:nil];
}

#pragma mark - playback controller delegation

- (void)prepareForMediaPlayback:(VLCPlaybackController *)controller
{
    APLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)appBecameActive:(NSNotification *)aNotification
{
    VLCPlayerDisplayController *pdc = [VLCPlayerDisplayController sharedInstance];
    if (pdc.displayMode == VLCPlayerDisplayControllerDisplayModeFullscreen) {
        VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
        [vpc recoverDisplayedMetadata];
        if (vpc.videoOutputView != self.movieView) {
            vpc.videoOutputView = nil;
            vpc.videoOutputView = self.movieView;
        }
    }
}

- (void)playbackDidStop:(NSNotification *)aNotification
{
    [[UIApplication sharedApplication] sendAction:@selector(closeFullscreenPlayback) to:nil from:self forEvent:nil];
}

- (void)mediaPlayerStateChanged:(VLCMediaPlayerState)currentState
                      isPlaying:(BOOL)isPlaying
currentMediaHasTrackToChooseFrom:(BOOL)currentMediaHasTrackToChooseFrom
        currentMediaHasChapters:(BOOL)currentMediaHasChapters
          forPlaybackController:(VLCPlaybackController *)controller
{
    if (controller.isPlaying && !self.bufferingLabel.hidden) {
        [UIView animateWithDuration:.3 animations:^{
            self.bufferingLabel.hidden = YES;
            self.bottomOverlayView.hidden = NO;
        }];
    }
}

- (void)displayMetadataForPlaybackController:(VLCPlaybackController *)controller
                                       title:(NSString *)title
                                     artwork:(UIImage *)artwork
                                      artist:(NSString *)artist
                                       album:(NSString *)album
                                   audioOnly:(BOOL)audioOnly
{
    self.titleLabel.text = title;
}

- (void)playbackPositionUpdated:(VLCPlaybackController *)controller
{
    VLCMediaPlayer *mediaPlayer = [VLCPlaybackController sharedInstance].mediaPlayer;
    self.remainingTimeLabel.text = [[mediaPlayer remainingTime] stringValue];
    self.playedTimeLabel.text = [[mediaPlayer time] stringValue];
    self.playbackProgressView.progress = mediaPlayer.position;
}

#pragma mark - controls visibility

- (void)touch:(UITapGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded)
    {
        [self toggleControlsVisible];
        [self _resetIdleTimer];
    }
}

- (void)playPause:(UITapGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded)
    {
        if (_controlsHidden)
            [self toggleControlsVisible];
        [self _resetIdleTimer];
        VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
        [vpc playPause];
    }
}

- (void)swipe:(UISwipeGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateEnded)
    {
        switch (gesture.direction)
        {
            case UISwipeGestureRecognizerDirectionLeft:
            {
                if (_controlsHidden)
                    [self toggleControlsVisible];
                [self _resetIdleTimer];
                VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
                [vpc backward];
                break;
            }
            case UISwipeGestureRecognizerDirectionRight:
            {
                if (_controlsHidden)
                    [self toggleControlsVisible];
                [self _resetIdleTimer];
                VLCPlaybackController *vpc = [VLCPlaybackController sharedInstance];
                [vpc forward];
                break;
            }
            case UISwipeGestureRecognizerDirectionDown:
            {
                // TODO : show settings menu
                break;
            }
            default:
            {
                break;
            }
        }
    }
}

- (void)setControlsHidden:(BOOL)hidden animated:(BOOL)animated
{
    _controlsHidden = hidden;
    CGFloat alpha = _controlsHidden? 0.0f: 1.0f;
    
    if (!_controlsHidden) {
        self.bottomOverlayView.alpha = 0.0f;
        self.swipeSettingsLabel.alpha = 0.0f;
    }
    
    void (^animationBlock)() = ^() {
        self.bottomOverlayView.alpha = alpha;
        self.swipeSettingsLabel.alpha = alpha;
    };
    
    void (^completionBlock)(BOOL finished) = ^(BOOL finished) {
        self.bottomOverlayView.hidden = _controlsHidden;
        self.swipeSettingsLabel.hidden = _controlsHidden;
    };
    
    NSTimeInterval animationDuration = animated? 0.3: 0.0;
    
    [UIView animateWithDuration:animationDuration animations:animationBlock completion:completionBlock];
}

- (void)_resetIdleTimer
{
    if (!_idleTimer)
        _idleTimer = [NSTimer scheduledTimerWithTimeInterval:3.
                                                      target:self
                                                    selector:@selector(idleTimerExceeded)
                                                    userInfo:nil
                                                     repeats:NO];
    else {
        if (fabs([_idleTimer.fireDate timeIntervalSinceNow]) < 3.)
            [_idleTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:3.]];
    }
}

- (void)toggleControlsVisible
{
    [self setControlsHidden:!_controlsHidden animated:YES];
}

- (void)idleTimerExceeded
{
    _idleTimer = nil;
    if (!_controlsHidden)
        [self toggleControlsVisible];
}

@end
