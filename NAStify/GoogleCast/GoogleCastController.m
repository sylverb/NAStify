//
//  GoogleCastController.m
//  NAStify
//
//  Created by Sylver Bruneau on 30/04/2014.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "GoogleCastController.h"
#import "private.h"

static NSString * kReceiverAppID;

@implementation GoogleCastController
+ (id)sharedGCController
{
    static GoogleCastController *sharedController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedController = [[self alloc] init];
        //You can add your own app id here that you get by registering with the Google Cast SDK Developer Console https://cast.google.com/publish
        kReceiverAppID=GOOGLECAST_RECEIVERID;
        
        // Hook up the logger.volumeChangeController
        [GCKLogger sharedInstance].delegate = sharedController;

        //Initialize device scanner
        sharedController.deviceScanner = [[GCKDeviceScanner alloc] init];
        
        [sharedController.deviceScanner addListener:sharedController];
        [sharedController.deviceScanner startScan];
    });
    return sharedController;
}

- (void)setPlaybackPercent:(float)newPercent {
    newPercent = MAX(MIN(1.0, newPercent), 0.0);
    
    NSTimeInterval newTime = newPercent * _streamDuration;
    if (_streamDuration > 0 && self.isConnected) {
        [self.mediaControlChannel seekToTimeInterval:newTime];
    }
}

#pragma mark - GCKDeviceScannerListener

- (void)callDelegateDidDiscoverDeviceOnNetwork
{
    [self.delegate didDiscoverDeviceOnNetwork];
}

- (void)callDelegateupdateGCState
{
    [self.delegate updateGCState];
}

- (void)deviceDidComeOnline:(GCKDevice *)device {
    NSLog(@"device found!! %@", device.friendlyName);
    if ([self.delegate respondsToSelector:@selector(didDiscoverDeviceOnNetwork)])
    {
        // Trigger an update in the next run loop so we pick up the updated devices array.
        [self performSelector:@selector(callDelegateDidDiscoverDeviceOnNetwork) withObject:nil afterDelay:0];
    }
}

- (void)deviceDidGoOffline:(GCKDevice *)device {
    if ([self.delegate respondsToSelector:@selector(updateGCState)])
    {
        // Trigger an update in the next run loop so we pick up the updated devices array.
        [self performSelector:@selector(callDelegateupdateGCState) withObject:nil afterDelay:0];
    }
}

#pragma mark - GCKDeviceManagerDelegate

- (void)deviceManagerDidConnect:(GCKDeviceManager *)deviceManager {
    NSLog(@"connected!!");
    
    [self.delegate updateGCState];
    [self.deviceManager launchApplication:kReceiverAppID];
}


- (void)deviceManager:(GCKDeviceManager *)deviceManager
didConnectToCastApplication:(GCKApplicationMetadata *)applicationMetadata
            sessionID:(NSString *)sessionID
  launchedApplication:(BOOL)launchedApplication {
    
    NSLog(@"application has launched");
    self.mediaControlChannel = [[GCKMediaControlChannel alloc] init];
    self.mediaControlChannel.delegate = self;
    [self.deviceManager addChannel:self.mediaControlChannel];
    [self.mediaControlChannel requestStatus];
    self.sessionID = sessionID;
    if ([self.delegate respondsToSelector:@selector(didConnectToDevice:)]) {
        [self.delegate didConnectToDevice:self.selectedDevice];
    }
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
didFailToConnectToApplicationWithError:(NSError *)error {
    [self showError:error];
    
    [self deviceDisconnected];
    [self.delegate updateGCState];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
didFailToConnectWithError:(GCKError *)error {
    [self showError:error];
    
    [self deviceDisconnected];
    [self.delegate updateGCState];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
volumeDidChangeToLevel:(float)volumeLevel
              isMuted:(BOOL)isMuted {
    NSLog(@"New volume level of %f reported!", volumeLevel);
    self.deviceVolume = volumeLevel;
    self.deviceMuted = isMuted;
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager didDisconnectWithError:(GCKError *)error {
    NSLog(@"Received notification that device disconnected");
    
    if (error != nil) {
        [self showError:error];
    }
    
    [self deviceDisconnected];
    [self.delegate updateGCState];
    
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager didReceiveApplicationMetadata:(GCKApplicationMetadata *)applicationMetadata
{
    self.applicationMetadata = applicationMetadata;
}

#pragma - GCKMediaControlChannelDelegate methods

- (void)mediaControlChannel:(GCKMediaControlChannel *)mediaControlChannel
didCompleteLoadWithSessionID:(NSInteger)sessionID {
    _mediaControlChannel = mediaControlChannel;
}

- (void)mediaControlChannelDidUpdateStatus:(GCKMediaControlChannel *)mediaControlChannel {
    [self updateStatsFromDevice];
    NSLog(@"Media control channel status changed");
    _mediaControlChannel = mediaControlChannel;
    if ([self.delegate respondsToSelector:@selector(didReceiveMediaStateChange)]) {
        [self.delegate didReceiveMediaStateChange];
    }
}

- (void)mediaControlChannelDidUpdateMetadata:(GCKMediaControlChannel *)mediaControlChannel {
    NSLog(@"Media control channel metadata changed");
    _mediaControlChannel = mediaControlChannel;
    [self updateStatsFromDevice];
    
    if ([self.delegate respondsToSelector:@selector(didReceiveMediaStateChange)]) {
        [self.delegate didReceiveMediaStateChange];
    }
}

- (BOOL)loadMedia:(NSURL *)url
     thumbnailURL:(NSURL *)thumbnailURL
            title:(NSString *)title
         subtitle:(NSString *)subtitle
         mimeType:(NSString *)mimeType
        startTime:(NSTimeInterval)startTime
         autoPlay:(BOOL)autoPlay {
    if (!self.deviceManager || !self.deviceManager.isConnected) {
        return NO;
    }
    
    GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];
    if (title) {
        [metadata setString:title forKey:kGCKMetadataKeyTitle];
    }
    
    if (subtitle) {
        [metadata setString:subtitle forKey:kGCKMetadataKeySubtitle];
    }
    
    if (thumbnailURL) {
        [metadata addImage:[[GCKImage alloc] initWithURL:thumbnailURL width:200 height:100]];
    }
    
    GCKMediaInformation *mediaInformation =
    [[GCKMediaInformation alloc] initWithContentID:[url absoluteString]
                                        streamType:GCKMediaStreamTypeNone
                                       contentType:mimeType
                                          metadata:metadata
                                    streamDuration:0
                                        customData:nil];
    [self.mediaControlChannel loadMedia:mediaInformation autoplay:autoPlay playPosition:startTime];
    
    return YES;
}

#pragma mark - Google Cast related functions

- (void)updateStatsFromDevice {
    
    if (self.isConnected && self.mediaControlChannel && self.mediaControlChannel.mediaStatus) {
        _streamPosition = [self.mediaControlChannel approximateStreamPosition];
        _streamDuration = self.mediaControlChannel.mediaStatus.mediaInformation.streamDuration;
        
        _playerState = self.mediaControlChannel.mediaStatus.playerState;
        _mediaInformation = self.mediaControlChannel.mediaStatus.mediaInformation;
    }
}

- (BOOL)isConnected {
    return self.deviceManager.isConnected;
}

- (void)connectToDevice {
    if (self.selectedDevice == nil)
        return;
    
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    self.deviceManager =
    [[GCKDeviceManager alloc] initWithDevice:self.selectedDevice
                           clientPackageName:[info objectForKey:@"CFBundleIdentifier"]];
    self.deviceManager.delegate = self;
    [self.deviceManager connect];
    
}

- (void)connectToDevice:(GCKDevice *)device {
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    self.selectedDevice = device;
    self.deviceManager =
    [[GCKDeviceManager alloc] initWithDevice:device
                           clientPackageName:[info objectForKey:@"CFBundleIdentifier"]];
    self.deviceManager.delegate = self;
    [self.deviceManager connect];
}

- (void)disconnectFromDevice {
    NSLog(@"Disconnecting device:%@", self.selectedDevice.friendlyName);
    // Stop the application
    [self.deviceManager stopApplication];
    [self.deviceManager disconnect];
    _mediaInformation = nil;
}

- (void)deviceDisconnected {
    self.mediaControlChannel = nil;
    self.deviceManager = nil;
    self.selectedDevice = nil;
    _mediaInformation = nil;
}

- (BOOL)isPlayingMedia {
    return self.deviceManager.isConnected && self.mediaControlChannel &&
    self.mediaControlChannel.mediaStatus && (self.playerState == GCKMediaPlayerStatePlaying ||
                                             self.playerState == GCKMediaPlayerStatePaused ||
                                             self.playerState == GCKMediaPlayerStateBuffering);
}

- (void)pauseCastMedia:(BOOL)shouldPause {
    if (self.isConnected && self.mediaControlChannel && self.mediaControlChannel.mediaStatus) {
        if (shouldPause) {
            [self.mediaControlChannel pause];
        } else {
            [self.mediaControlChannel play];
        }
    }
}

#pragma mark - misc
- (void)showError:(NSError *)error {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                    message:NSLocalizedString(error.description, nil)
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - GCKLoggerDelegate implementation

- (void)logFromFunction:(const char *)function message:(NSString *)message {
    // Send SDK’s log messages directly to the console, as an example.
//    NSLog(@"%s  %@", function, message);
}

@end
