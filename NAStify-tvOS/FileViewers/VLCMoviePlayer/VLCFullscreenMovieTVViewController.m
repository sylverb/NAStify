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
    
    UISwipeGestureRecognizer *_swipeRecognizerUp;
    UISwipeGestureRecognizer *_swipeRecognizerDown;
    UISwipeGestureRecognizer *_swipeRecognizerLeft;
    UISwipeGestureRecognizer *_swipeRecognizerRight;
    UITapGestureRecognizer *_touchRecognizer;
    UITapGestureRecognizer *_playRecognizer;
    
    UITabBarController *_settingsTabBar;
    
    BOOL _switchingTracksNotChapters;
    UITableView *_trackSelectorTableView;
    VLCFrostedGlasView *_trackSelectorContainer;
}
@end

@implementation VLCFullscreenMovieTVViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_swipeRecognizerUp)
        [self.view removeGestureRecognizer:_swipeRecognizerUp];
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

    _swipeRecognizerUp = nil;
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
    _swipeRecognizerUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                   action:@selector(swipe:)];
    _swipeRecognizerUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:_swipeRecognizerUp];
    
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

    _settingsTabBar = [[UITabBarController alloc] init];
    NSArray *navControllersArray = [NSArray arrayWithObjects:
                                    settingsNavController,
                                    nil];
    _settingsTabBar.viewControllers = navControllersArray;
    _settingsTabBar.view.frame = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height / 2);
    _settingsTabBar.view.backgroundColor = [UIColor grayColor];
    _settingsTabBar.tabBar.backgroundColor = [UIColor grayColor];
    [_settingsTabBar.tabBar setValue:@(YES) forKeyPath:@"_hidesShadow"];
    
    // Setup views
    _trackSelectorTableView = [[UITableView alloc] initWithFrame:CGRectMake(0., 0., 1920.0, 450.0) style:UITableViewStylePlain];
    _trackSelectorTableView.delegate = self;
    _trackSelectorTableView.dataSource = self;
    _trackSelectorTableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [_trackSelectorTableView registerClass:[VLCTrackSelectorTableViewCell class] forCellReuseIdentifier:TRACK_SELECTOR_TABLEVIEW_CELL];
    [_trackSelectorTableView registerClass:[VLCTrackSelectorHeaderView class] forHeaderFooterViewReuseIdentifier:TRACK_SELECTOR_TABLEVIEW_SECTIONHEADER];
    _trackSelectorTableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    _trackSelectorContainer = [[VLCFrostedGlasView alloc] initWithFrame:CGRectMake(0, 0, 1920, 1080)];
    [_trackSelectorContainer addSubview:_trackSelectorTableView];
    _trackSelectorContainer.hidden = YES;
    
    _trackSelectorTableView.opaque = NO;
    _trackSelectorTableView.backgroundColor = [UIColor grayColor];
    _trackSelectorTableView.allowsMultipleSelection = YES;
    
    _switchingTracksNotChapters = YES;
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

    [vpc stopPlayback];
    
    [_trackSelectorTableView removeFromSuperview];
    
    [super viewWillDisappear:animated];
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
                //FIXME : show settings menu animated
                VLCMediaPlayer *mediaPlayer = [VLCPlaybackController sharedInstance].mediaPlayer;
                if (([mediaPlayer numberOfAudioTracks] > 2) ||
                    ([mediaPlayer numberOfSubtitlesTracks] > 0))
                {
                    [self.view addSubview:_trackSelectorTableView];
                }
                
                break;
            }
            case UISwipeGestureRecognizerDirectionUp:
            {
                // Hide settings menu if focus is on first cell
                if ([_trackSelectorTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].isFocused)
                    [_trackSelectorTableView removeFromSuperview];
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

#pragma mark - track selector table view
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger ret = 0;
    VLCMediaPlayer *mediaPlayer = [VLCPlaybackController sharedInstance].mediaPlayer;
    
    if (_switchingTracksNotChapters == YES) {
        if (mediaPlayer.audioTrackIndexes.count > 2)
            ret++;
        
        if (mediaPlayer.videoSubTitlesIndexes.count > 1)
            ret++;
    } else {
        if ([mediaPlayer numberOfTitles] > 1)
            ret++;
        
        if ([mediaPlayer numberOfChaptersForTitle:mediaPlayer.currentTitleIndex] > 1)
            ret++;
    }
    
    return ret;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UITableViewHeaderFooterView *view = [tableView dequeueReusableHeaderFooterViewWithIdentifier:TRACK_SELECTOR_TABLEVIEW_SECTIONHEADER];
    
    if (!view)
        view = [[VLCTrackSelectorHeaderView alloc] initWithReuseIdentifier:TRACK_SELECTOR_TABLEVIEW_SECTIONHEADER];
    
    return view;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    VLCMediaPlayer *mediaPlayer = [VLCPlaybackController sharedInstance].mediaPlayer;
    
    if (_switchingTracksNotChapters == YES) {
        if (mediaPlayer.audioTrackIndexes.count > 2 && section == 0)
            return NSLocalizedString(@"CHOOSE_AUDIO_TRACK", nil);
        
        if (mediaPlayer.videoSubTitlesIndexes.count > 1)
            return NSLocalizedString(@"CHOOSE_SUBTITLE_TRACK", nil);
    } else {
        if ([mediaPlayer numberOfTitles] > 1 && section == 0)
            return NSLocalizedString(@"CHOOSE_TITLE", nil);
        
        if ([mediaPlayer numberOfChaptersForTitle:mediaPlayer.currentTitleIndex] > 1)
            return NSLocalizedString(@"CHOOSE_CHAPTER", nil);
    }
    
    return @"unknown track type";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    VLCTrackSelectorTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TRACK_SELECTOR_TABLEVIEW_CELL];
    
    if (!cell)
        cell = [[VLCTrackSelectorTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TRACK_SELECTOR_TABLEVIEW_CELL];
    
    NSInteger row = indexPath.row;
    NSInteger section = indexPath.section;
    VLCMediaPlayer *mediaPlayer = [VLCPlaybackController sharedInstance].mediaPlayer;
    BOOL cellShowsCurrentTrack = NO;
    
    if (_switchingTracksNotChapters == YES) {
        NSArray *indexArray;
        NSString *trackName;
        if ([mediaPlayer numberOfAudioTracks] > 2 && section == 0) {
            indexArray = mediaPlayer.audioTrackIndexes;
            
            if ([indexArray indexOfObject:[NSNumber numberWithInt:mediaPlayer.currentAudioTrackIndex]] == row)
                cellShowsCurrentTrack = YES;
            
            trackName = mediaPlayer.audioTrackNames[row];
        } else {
            indexArray = mediaPlayer.videoSubTitlesIndexes;
            
            if ([indexArray indexOfObject:[NSNumber numberWithInt:mediaPlayer.currentVideoSubTitleIndex]] == row)
                cellShowsCurrentTrack = YES;
            
            trackName = mediaPlayer.videoSubTitlesNames[row];
        }
        
        if (trackName != nil) {
            if ([trackName isEqualToString:@"Disable"])
                cell.textLabel.text = NSLocalizedString(@"DISABLE_LABEL", nil);
            else
                cell.textLabel.text = trackName;
        }
    } else {
        if ([mediaPlayer numberOfTitles] > 1 && section == 0) {
            NSDictionary *description = mediaPlayer.titleDescriptions[row];
            cell.textLabel.text = [NSString stringWithFormat:@"%@ (%@)", description[VLCTitleDescriptionName], [[VLCTime timeWithNumber:description[VLCTitleDescriptionDuration]] stringValue]];
            
            if (row == mediaPlayer.currentTitleIndex)
                cellShowsCurrentTrack = YES;
        } else {
            NSDictionary *description = [mediaPlayer chapterDescriptionsOfTitle:mediaPlayer.currentTitleIndex][row];
            cell.textLabel.text = [NSString stringWithFormat:@"%@ (%@)", description[VLCChapterDescriptionName], [[VLCTime timeWithNumber:description[VLCChapterDescriptionDuration]] stringValue]];
            
            if (row == mediaPlayer.currentChapterIndex)
                cellShowsCurrentTrack = YES;
        }
    }
    [cell setShowsCurrentTrack:cellShowsCurrentTrack];
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    VLCMediaPlayer *mediaPlayer = [VLCPlaybackController sharedInstance].mediaPlayer;
    
    if (_switchingTracksNotChapters == YES) {
        NSInteger audioTrackCount = mediaPlayer.audioTrackIndexes.count;
        
        if (audioTrackCount > 2 && section == 0)
            return audioTrackCount;
        
        return mediaPlayer.videoSubTitlesIndexes.count;
    } else {
        if ([mediaPlayer numberOfTitles] > 1 && section == 0)
            return [mediaPlayer numberOfTitles];
        else
            return [mediaPlayer numberOfChaptersForTitle:mediaPlayer.currentTitleIndex];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    NSInteger index = indexPath.row;
    VLCMediaPlayer *mediaPlayer = [VLCPlaybackController sharedInstance].mediaPlayer;
    
    if (_switchingTracksNotChapters == YES) {
        NSArray *indexArray;
        if (mediaPlayer.audioTrackIndexes.count > 2 && indexPath.section == 0) {
            indexArray = mediaPlayer.audioTrackIndexes;
            if (index <= indexArray.count)
                mediaPlayer.currentAudioTrackIndex = [indexArray[index] intValue];
            
        } else {
            indexArray = mediaPlayer.videoSubTitlesIndexes;
            if (index <= indexArray.count)
                mediaPlayer.currentVideoSubTitleIndex = [indexArray[index] intValue];
        }
    } else {
        if ([mediaPlayer numberOfTitles] > 1 && indexPath.section == 0)
            mediaPlayer.currentTitleIndex = (int)index;
        else
            mediaPlayer.currentChapterIndex = (int)index;
    }
    
    CGFloat alpha = 0.0f;
    _trackSelectorContainer.alpha = 1.0f;
    
    void (^animationBlock)() = ^() {
        _trackSelectorContainer.alpha = alpha;
    };
    
    void (^completionBlock)(BOOL finished) = ^(BOOL finished) {
        for (UIGestureRecognizer *recognizer in self.view.gestureRecognizers)
            [recognizer setEnabled:YES];
        _trackSelectorContainer.hidden = YES;
    };
    
    NSTimeInterval animationDuration = .3;
    [UIView animateWithDuration:animationDuration animations:animationBlock completion:completionBlock];
    
    [tableView reloadData];
}


@end
