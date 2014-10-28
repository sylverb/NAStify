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
#define kVLCSettingContinueAudioInBackgroundKey @"BackgroundAudioPlayback"
#define kVLCSettingStretchAudio @"audio-time-stretch"
#define kVLCSettingStretchAudioOnValue @"1"
#define kVLCSettingStretchAudioOffValue @"0"
#define kVLCSettingSkipLoopFilter @"avcodec-skiploopfilter"
#define kVLCSettingSkipLoopFilterNone @(0)
#define kVLCSettingSkipLoopFilterNonRef @(1)
#define kVLCSettingSkipLoopFilterNonKey @(3)
#define kVLCSettingPlaybackGestures @"EnableGesturesToControlPlayback"
#define kVLCShowRemainingTime @"show-remaining-time"
#define kVLCSettingDeinterlace @"deinterlace"
#define kVLCSettingDeinterlaceDefaultValue @(0)
#define kVLCSettingNetworkCaching @"network-caching"
#define kVLCSettingNetworkCachingDefaultValue @(999)
#define kVLCSettingTextEncoding @"subsdec-encoding"
#define kVLCSettingTextEncodingDefaultValue @"Windows-1252"
#define kVLCSettingSubtitlesFont @"quartztext-font"
#define kVLCSettingSubtitlesFontDefaultValue @"HelveticaNeue"
#define kVLCSettingSubtitlesFontSize @"quartztext-rel-fontsize"
#define kVLCSettingSubtitlesFontSizeDefaultValue @"16"
#define kVLCSettingSubtitlesBoldFont @"quartztext-bold"
#define kVLCSettingSubtitlesBoldFontDefaulValue @NO
#define kVLCSettingSubtitlesFontColor @"quartztext-color"
#define kVLCSettingSubtitlesFontColorDefaultValue @"16777215"

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
