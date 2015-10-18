//
//  VlcSettingsViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TableSelectViewController.h"

#define kBlobHash @"521923d214b9ae628da7987cf621e94c4afdd726"
#define kVLCSettingPasscodeKey @"Passcode"
#define kVLCSettingPasscodeOnKey @"PasscodeProtection"
#define kVLCSettingContinueAudioInBackgroundKey @"BackgroundAudioPlayback"
#define kVLCSettingStretchAudio @"audio-time-stretch"
#define kVLCSettingStretchAudioOnValue @"1"
#define kVLCSettingStretchAudioOffValue @"0"
#define kVLCSettingTextEncoding @"subsdec-encoding"
#define kVLCSettingTextEncodingDefaultValue @"Windows-1252"
#define kVLCSettingSkipLoopFilter @"avcodec-skiploopfilter"
#define kVLCSettingSkipLoopFilterNone @(0)
#define kVLCSettingSkipLoopFilterNonRef @(1)
#define kVLCSettingSkipLoopFilterNonKey @(3)
#define kVLCSettingSaveHTTPUploadServerStatus @"isHTTPServerOn"
#define kVLCSettingSubtitlesFont @"quartztext-font"
#define kVLCSettingSubtitlesFontDefaultValue @"HelveticaNeue"
#define kVLCSettingSubtitlesFontSize @"quartztext-rel-fontsize"
#define kVLCSettingSubtitlesFontSizeDefaultValue @"16"
#define kVLCSettingSubtitlesBoldFont @"quartztext-bold"
#define kVLCSettingSubtitlesBoldFontDefaultValue @NO
#define kVLCSettingSubtitlesFontColor @"quartztext-color"
#define kVLCSettingSubtitlesFontColorDefaultValue @"16777215"
#define kVLCSettingSubtitlesFilePath @"sub-file"
#define kVLCSettingDeinterlace @"deinterlace"
#define kVLCSettingDeinterlaceDefaultValue @(0)
#define kVLCSettingNetworkCaching @"network-caching"
#define kVLCSettingNetworkCachingDefaultValue @(999)
#define kVLCSettingsDecrapifyTitles @"MLDecrapifyTitles"
#define kVLCSettingVolumeGesture @"EnableVolumeGesture"
#define kVLCSettingPlayPauseGesture @"EnablePlayPauseGesture"
#define kVLCSettingBrightnessGesture @"EnableBrightnessGesture"
#define kVLCSettingSeekGesture @"EnableSeekGesture"
#define kVLCSettingCloseGesture @"EnableCloseGesture"
#define kVLCSettingVariableJumpDuration @"EnableVariableJumpDuration"
#define kVLCSettingVideoFullscreenPlayback @"AlwaysUseFullscreenForVideo"
#define kVLCSettingContinuePlayback @"ContinuePlayback"
#define kVLCSettingFTPTextEncoding @"ftp-text-encoding"
#define kVLCSettingFTPTextEncodingDefaultValue @(5) // ISO Latin 1
#define kVLCSettingPlaybackSpeedDefaultValue @"playback-speed"
#define kVLCSettingWiFiSharingIPv6 @"wifi-sharing-ipv6"
#define kVLCSettingWiFiSharingIPv6DefaultValue @(NO)
#define kVLCSettingEqualizerProfile @"EqualizerProfile"
#define kVLCSettingEqualizerProfileDefaultValue @(0)
#define kVLCSettingPlaybackForwardSkipLength @"playback-forward-skip-length"
#define kVLCSettingPlaybackForwardSkipLengthDefaultValue @(60)
#define kVLCSettingPlaybackBackwardSkipLength @"playback-forward-skip-length"
#define kVLCSettingPlaybackBackwardSkipLengthDefaultValue @(60)
#define kVLCSettingOpenAppForPlayback @"open-app-for-playback"
#define kVLCSettingOpenAppForPlaybackDefaultValue @YES
#define kVLCSettingPlaybackGestures @"EnableGesturesToControlPlayback"

#define kVLCShowRemainingTime @"show-remaining-time"
#define kVLCRecentURLs @"recent-urls"
#define kVLCPrivateWebStreaming @"private-streaming"
#define kVLChttpScanSubtitle @"http-scan-subtitle"

#define kNASTifySettingPlayerType       @"VideoPlayerType"
#define kNASTifySettingPlayerTypeInternal           0
#define kNASTifySettingPlayerTypeExternal           1
#define kNASTifySettingInternalPlayer   @"VideoPlayer"
#define kNASTifySettingInternalPlayerTypeQTVLC      0
#define kNASTifySettingInternalPlayerTypeVLCOnly    1
#define kNASTifySettingExternalPlayer   @"ExternalVideoPlayer"
#define kNASTifySettingExternalPlayerType   @"ExternalVideoPlayerType"
#define kNASTifySettingExternalPlayerTypeVlc        0
#define kNASTifySettingExternalPlayerTypeAceplayer  1
#define kNASTifySettingExternalPlayerTypeGplayer    2
#define kNASTifySettingExternalPlayerTypeOplayer    3
#define kNASTifySettingExternalPlayerTypeGoodplayer 4
#define kNASTifySettingExternalPlayerTypePlex       5

#define kSupportedSubtitleFileExtensions @"\\.(srt|sub|cdg|idx|utf|ass|ssa|aqt|jss|psb|rt|smi|txt|smil)$"

@interface VlcSettingsViewController : UITableViewController <TableSelectViewControllerDelegate>

// libVLC settings
@property (nonatomic, strong) NSArray *cachingValues;
@property (nonatomic, strong) NSArray *cachingNames;
@property (nonatomic) NSInteger cachingIndex;
@property (nonatomic, strong) NSArray *skipLoopValues;
@property (nonatomic) NSInteger skipLoopIndex;
@property (nonatomic, strong) NSArray *fontValues;
@property (nonatomic, strong) NSArray *fontNames;
@property (nonatomic) NSInteger fontIndex;
@property (nonatomic, strong) NSArray *fontSizeValues;
@property (nonatomic, strong) NSArray *fontSizeNames;
@property (nonatomic) NSInteger fontSizeIndex;
@property (nonatomic, strong) NSArray *fontColorValues;
@property (nonatomic, strong) NSArray *fontColorNames;
@property (nonatomic) NSInteger fontColorIndex;
@property (nonatomic, strong) NSArray *textEncodingValues;
@property (nonatomic, strong) NSArray *textEncodingNames;
@property (nonatomic) NSInteger textEncodingIndex;

@end
