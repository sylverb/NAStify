//
//  GoogleCastController.h
//  NAStify
//
//  Created by Sylver Bruneau on 30/04/2014.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GoogleCast/GoogleCast.h>

@protocol GCControllerDelegate <NSObject>
- (void)updateGCState;
- (void)didDiscoverDeviceOnNetwork;
@optional
- (void)didReceiveMediaStateChange;
- (void)didConnectToDevice:(GCKDevice *)device;
@end

@interface GoogleCastController : NSObject <GCKDeviceScannerListener, GCKDeviceManagerDelegate, GCKMediaControlChannelDelegate, GCKLoggerDelegate>


/* Google Cast handling */
@property GCKMediaControlChannel *mediaControlChannel;
@property GCKApplicationMetadata *applicationMetadata;
@property GCKDevice *selectedDevice;
@property(nonatomic, strong) GCKDeviceScanner *deviceScanner;
@property(nonatomic, strong) GCKDeviceManager *deviceManager;
@property(nonatomic, readonly) GCKMediaInformation *mediaInformation;
@property(nonatomic, readonly) GCKMediaPlayerState playerState;
@property(nonatomic, strong) NSString *sessionID;
@property(nonatomic, readonly) NSTimeInterval streamDuration;
@property(nonatomic, readonly) NSTimeInterval streamPosition;
@property float deviceVolume;
@property bool deviceMuted;

@property(nonatomic, strong) id<GCControllerDelegate> delegate;

+ (id)sharedGCController;
- (BOOL)isConnected;
- (void)updateStatsFromDevice;
- (void)connectToDevice:(GCKDevice *)device;
- (void)disconnectFromDevice;
- (void)connectToDevice;
- (void)deviceDisconnected;
- (BOOL)isPlayingMedia;
- (void)pauseCastMedia:(BOOL)shouldPause;
@end
