//
//  VlcSettingsViewController.m
//  NAStify
//
//  Created by Sylver Bruneau on 16/04/2014.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "VlcSettingsViewController.h"
#if TARGET_OS_IOS
#import "SwitchCell.h"
#elif TARGET_OS_TV
#import "SegCtrlCell.h"
#endif
#import "TextCell.h"
#import "SDImageCache.h"

#if TARGET_OS_IOS
#define SETTINGS_GENERIC_SECTION_INDEX 0
#define SETTINGS_VIDEO_SECTION_INDEX 1
#define SETTINGS_SUBTITLES_SECTION_INDEX 2
#define SETTINGS_AUDIO_SECTION_INDEX 3
#elif TARGET_OS_TV
#define SETTINGS_GENERIC_SECTION_INDEX 0
#define SETTINGS_VIDEO_SECTION_INDEX 1
#define SETTINGS_AUDIO_SECTION_INDEX 3
#endif

#define TAG_CACHING             0
#define TAG_SKIPLOOPFILTER      1
#define TAG_DEINTERLACE         2
#define TAG_FONT_NAME           3
#define TAG_FONT_SIZE           4
#define TAG_FONT_BOLD           5
#define TAG_FONT_COLOR          6
#define TAG_TEXT_ENCODING       7
#define TAG_AUDIO_STRETCHING    8
#define TAG_AUDIO_BACKGROUND    9

@interface VlcSettingsViewController ()

@end

@implementation VlcSettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self)
    {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    NSInteger index;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Internal VLC player settings", nil);
    
    // Network caching options
    self.cachingNames = [NSArray arrayWithObjects:
                         NSLocalizedString(@"Lowest Latency",nil),
                         NSLocalizedString(@"Low Latency",nil),
                         NSLocalizedString(@"Normal",nil),
                         NSLocalizedString(@"High Latency",nil),
                         NSLocalizedString(@"Highest Latency",nil),
                         nil];
    
    self.cachingValues = [NSArray arrayWithObjects:
                       @(333),
                       @(666),
                       @(999),
                       @(1667),
                       @(3333),
                       nil];
    
    self.cachingIndex = 2;
    for (index = 0;index <[self.cachingValues count];index++)
    {
        if ([[self.cachingValues objectAtIndex:index] isEqualToNumber:[defaults objectForKey:kVLCSettingNetworkCaching]])
        {
            self.cachingIndex = index;
            break;
        }
    }

    // Deblocking options
    self.skipLoopValues = [NSArray arrayWithObjects:
                           NSLocalizedString(@"No deblocking (fastest)",nil),
                           NSLocalizedString(@"Medium deblocking",nil),
                           NSLocalizedString(@"Low deblocking",nil),
                           nil];
    self.skipLoopIndex = 1;
    
    if ([[defaults objectForKey:kVLCSettingSkipLoopFilter] isEqualToNumber:kVLCSettingSkipLoopFilterNone])
    {
        self.skipLoopIndex = 0;
    }
    else if ([[defaults objectForKey:kVLCSettingSkipLoopFilter] isEqualToNumber:kVLCSettingSkipLoopFilterNonRef])
    {
        self.skipLoopIndex = 1;
    }
    else if ([[defaults objectForKey:kVLCSettingSkipLoopFilter] isEqualToNumber:kVLCSettingSkipLoopFilterNonKey])
    {
        self.skipLoopIndex = 2;
    }
    
    self.fontValues = [NSArray arrayWithObjects:
                       @"AmericanTypewriter",
                       @"ArialMT",
                       @"ArialHebrew",
                       @"ChalkboardSE-Regular",
                       @"CourierNewPSMT",
                       @"Georgia",
                       @"GillSans",
                       @"GujaratiSangamMN",
                       @"STHeitiSC-Light",
                       @"STHeitiTC-Light",
                       @"HelveticaNeue",
                       @"HiraKakuProN-W3",
                       @"HiraMinProN-W3",
                       @"HoeflerText-Regular",
                       @"Kailasa",
                       @"KannadaSangamMN",
                       @"MalayalamSangamMN",
                       @"OriyaSangamMN",
                       @"SinhalaSangamMN",
                       @"SnellRoundhand",
                       @"TamilSangamMN",
                       @"TeluguSangamMN",
                       @"TimesNewRomanPSMT",
                       @"Zapfino",
                       nil];

    self.fontNames = [NSArray arrayWithObjects:
                      NSLocalizedString(@"American Typewriter",nil),
                      NSLocalizedString(@"Arial",nil),
                      NSLocalizedString(@"Arial Hebrew",nil),
                      NSLocalizedString(@"Chalkboard SE",nil),
                      NSLocalizedString(@"Courier New",nil),
                      NSLocalizedString(@"Georgia",nil),
                      NSLocalizedString(@"Gill Sans",nil),
                      NSLocalizedString(@"Gujarati Sangam MN",nil),
                      NSLocalizedString(@"Heiti SC",nil),
                      NSLocalizedString(@"Heiti TC",nil),
                      NSLocalizedString(@"Helvetica Neue",nil),
                      NSLocalizedString(@"Hiragino Kaku Gothic ProN",nil),
                      NSLocalizedString(@"Hiragino Mincho ProN",nil),
                      NSLocalizedString(@"Hoefler Text",nil),
                      NSLocalizedString(@"Kailasa",nil),
                      NSLocalizedString(@"Kannada Sangam MN",nil),
                      NSLocalizedString(@"Malayalam Sangam MN",nil),
                      NSLocalizedString(@"Oriya Sangam MN",nil),
                      NSLocalizedString(@"Sinhala Sangam MN",nil),
                      NSLocalizedString(@"Snell Roundhand",nil),
                      NSLocalizedString(@"Tamil Sangam MN",nil),
                      NSLocalizedString(@"Telugu Sangam MN",nil),
                      NSLocalizedString(@"Times New Roman",nil),
                      NSLocalizedString(@"Zapfino",nil),
                      nil];
    
    self.fontIndex = 0;
    for (index = 0;index <[self.fontValues count];index++)
    {
        if ([[self.fontValues objectAtIndex:index] isEqualToString:[defaults objectForKey:kVLCSettingSubtitlesFont]])
        {
            self.fontIndex = index;
            break;
        }
    }

    self.fontSizeValues = [NSArray arrayWithObjects:
                          @"20",
                          @"18",
                          @"16",
                          @"12",
                          @"6",
                          nil];
    
    self.fontSizeNames = [NSArray arrayWithObjects:
                          NSLocalizedString(@"Smallest",nil),
                          NSLocalizedString(@"Small",nil),
                          NSLocalizedString(@"Normal",nil),
                          NSLocalizedString(@"Large",nil),
                          NSLocalizedString(@"Largest",nil),
                          nil];
    
    self.fontSizeIndex = 0;
    for (index = 0;index <[self.fontSizeValues count];index++)
    {
        if ([[self.fontSizeValues objectAtIndex:index] isEqualToString:[defaults objectForKey:kVLCSettingSubtitlesFontSize]])
        {
            self.fontSizeIndex = index;
            break;
        }
    }
    
    self.fontColorValues = [NSArray arrayWithObjects:
                            @"16777215",
                            @"0",
                            @"8421504",
                            @"12632256",
                            @"16711680",
                            @"16711935",
                            @"16776960",
                            @"32768",
                            @"128",
                            nil];
    
    self.fontColorNames = [NSArray arrayWithObjects:
                           NSLocalizedString(@"White",nil),
                           NSLocalizedString(@"Black",nil),
                           NSLocalizedString(@"Gray",nil),
                           NSLocalizedString(@"Silver",nil),
                           NSLocalizedString(@"Red",nil),
                           NSLocalizedString(@"Fuchsia",nil),
                           NSLocalizedString(@"Yellow",nil),
                           NSLocalizedString(@"Green",nil),
                           NSLocalizedString(@"Navy",nil),
                           nil];
    
    self.fontColorIndex = 0;
    for (index = 0;index <[self.fontColorValues count];index++)
    {
        if ([[self.fontColorValues objectAtIndex:index] isEqualToString:[defaults objectForKey:kVLCSettingSubtitlesFontColor]])
        {
            self.fontColorIndex = index;
            break;
        }
    }
    
    self.textEncodingValues = [NSArray arrayWithObjects:
                               @"UTF-8",
                               @"UTF-16",
                               @"UTF-16BE",
                               @"UTF-16LE",
                               @"GB18030",
                               @"ISO-8859-15",
                               @"Windows-1252",
                               @"IBM850",
                               @"ISO-8859-2",
                               @"Windows-1250",
                               @"ISO-8859-3",
                               @"ISO-8859-10",
                               @"Windows-1251",
                               @"KOI8-R",
                               @"KOI8-U",
                               @"ISO-8859-6",
                               @"Windows-1256",
                               @"ISO-8859-7",
                               @"Windows-1253",
                               @"ISO-8859-8",
                               @"Windows-1255",
                               @"ISO-8859-9",
                               @"Windows-1254",
                               @"ISO-8859-11",
                               @"Windows-874",
                               @"ISO-8859-13",
                               @"Windows-1257",
                               @"ISO-8859-14",
                               @"ISO-8859-16",
                               @"ISO-2022-CN-EXT",
                               @"EUC-CN",
                               @"ISO-2022-JP-2",
                               @"EUC-JP",
                               @"Shift_JIS",
                               @"CP949",
                               @"ISO-2022-KR",
                               @"Big5",
                               @"ISO-2022-TW",
                               @"Big5-HKSCS",
                               @"VISCII",
                               @"Windows-1258",
                               nil];
    
    self.textEncodingNames = [NSArray arrayWithObjects:
                              NSLocalizedString(@"Universal (UTF-8)",nil),
                              NSLocalizedString(@"Universal (UTF-16)",nil),
                              NSLocalizedString(@"Universal (big endian UTF-16)",nil),
                              NSLocalizedString(@"Universal (little endian UTF-16)",nil),
                              NSLocalizedString(@"Universal Chinese (GB18030)",nil),
                              NSLocalizedString(@"Western European (Latin-9)",nil),
                              NSLocalizedString(@"Western European (Windows-1252)",nil),
                              NSLocalizedString(@"Western European (IBM 00850)",nil),
                              NSLocalizedString(@"Eastern European (Latin-2)",nil),
                              NSLocalizedString(@"Eastern European (Windows-1250)",nil),
                              NSLocalizedString(@"Esperanto (Latin-3)",nil),
                              NSLocalizedString(@"Nordic (Latin-6)",nil),
                              NSLocalizedString(@"Cyrillic (Windows-1251)",nil),
                              NSLocalizedString(@"Russian (KOI8-R)",nil),
                              NSLocalizedString(@"Ukrainian (KOI8-U)",nil),
                              NSLocalizedString(@"Arabic (ISO 8859-6)",nil),
                              NSLocalizedString(@"Arabic (Windows-1256)",nil),
                              NSLocalizedString(@"Greek (ISO 8859-7)",nil),
                              NSLocalizedString(@"Greek (Windows-1253)",nil),
                              NSLocalizedString(@"Hebrew (ISO 8859-8)",nil),
                              NSLocalizedString(@"Hebrew (Windows-1255)",nil),
                              NSLocalizedString(@"Turkish (ISO 8859-9)",nil),
                              NSLocalizedString(@"Turkish (Windows-1254)",nil),
                              NSLocalizedString(@"Thai (TIS 620-2533/ISO 8859-11)",nil),
                              NSLocalizedString(@"Thai (Windows-874)",nil),
                              NSLocalizedString(@"Baltic (Latin-7)",nil),
                              NSLocalizedString(@"Baltic (Windows-1257)",nil),
                              NSLocalizedString(@"Celtic (Latin-8)",nil),
                              NSLocalizedString(@"South-Eastern European (Latin-10)",nil),
                              NSLocalizedString(@"Simplified Chinese (ISO-2022-CN-EXT)",nil),
                              NSLocalizedString(@"Simplified Chinese Unix (EUC-CN)",nil),
                              NSLocalizedString(@"Japanese (7-bits JIS/ISO-2022-JP-2)",nil),
                              NSLocalizedString(@"Japanese Unix (EUC-JP)",nil),
                              NSLocalizedString(@"Japanese (Shift JIS)",nil),
                              NSLocalizedString(@"Korean (EUC-KR/CP949)",nil),
                              NSLocalizedString(@"Korean (ISO-2022-KR)",nil),
                              NSLocalizedString(@"Traditional Chinese (Big5)",nil),
                              NSLocalizedString(@"Traditional Chinese Unix (EUC-TW)",nil),
                              NSLocalizedString(@"Hong-Kong Supplementary (HKSCS)",nil),
                              NSLocalizedString(@"Vietnamese (VISCII)",nil),
                              NSLocalizedString(@"Vietnamese (Windows-1258)",nil),
                              nil];
    
    self.textEncodingIndex = 0;
    for (index = 0;index <[self.textEncodingValues count];index++)
    {
        if ([[self.textEncodingValues objectAtIndex:index] isEqualToString:[defaults objectForKey:kVLCSettingTextEncoding]])
        {
            self.textEncodingIndex = index;
            break;
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    //FIXME: implement filebrowser options
    // Return the number of rows in the section.
    NSInteger numberOfRows = 0;

    switch (section)
    {
        case SETTINGS_GENERIC_SECTION_INDEX:
        {
            numberOfRows = 1;
            break;
        }
        case SETTINGS_VIDEO_SECTION_INDEX:
        {
            numberOfRows = 2;
            break;
        }
#if TARGET_OS_IOS
        case SETTINGS_SUBTITLES_SECTION_INDEX:
        {
            numberOfRows = 5;
            break;
        }
#endif
        case SETTINGS_AUDIO_SECTION_INDEX:
        {
            numberOfRows = 2;
            break;
        }
        default:
        {
            break;
        }
    }
    return numberOfRows;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString * title = nil;
    
    switch (section)
    {
        case SETTINGS_GENERIC_SECTION_INDEX:
        {
            title = NSLocalizedString(@"Generic",nil);
            break;
        }
        case SETTINGS_VIDEO_SECTION_INDEX:
        {
            title = NSLocalizedString(@"Video",nil);
            break;
        }
#if TARGET_OS_IOS
        case SETTINGS_SUBTITLES_SECTION_INDEX:
        {
            title = NSLocalizedString(@"Subtitles",nil);
            break;
        }
#endif
        case SETTINGS_AUDIO_SECTION_INDEX:
        {
            title = NSLocalizedString(@"Audio",nil);
            break;
        }
        default:
        {
            break;
        }
    }
    return title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *TextCellIdentifier = @"TextCell";
#if TARGET_OS_IOS
	static NSString *SwitchCellIdentifier = @"SwitchCell";
#elif TARGET_OS_TV
    static NSString *SegmentedCellIdentifier = @"SegmentedCell";
#endif
    UITableViewCell *cell = nil;
    
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];

    switch (indexPath.section)
    {
        case SETTINGS_GENERIC_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    TextCell *textCell = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCell == nil)
                    {
                        textCell = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:TextCellIdentifier];
                    }
                    [textCell setCellDataWithLabelString:NSLocalizedString(@"Network Caching Level", nil)
                                                withText:[self.cachingNames objectAtIndex:self.cachingIndex]
                                         withPlaceHolder:nil
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeDefault
                                            withDelegate:nil
                                                  andTag:-1];
                    textCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    textCell.textField.enabled = NO;
                    textCell.canFocusContent = NO;

                    cell = textCell;
                    break;
                }
                default:
                {
                    break;
                }
            }
            break;
        }
        case SETTINGS_VIDEO_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    TextCell *textCell = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCell == nil)
                    {
                        textCell = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:TextCellIdentifier];
                    }
                    [textCell setCellDataWithLabelString:NSLocalizedString(@"Deblocking filter", nil)
                                                withText:[self.skipLoopValues objectAtIndex:self.skipLoopIndex]
                                         withPlaceHolder:nil
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeDefault
                                            withDelegate:nil
                                                  andTag:-1];
                    textCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    textCell.textField.enabled = NO;
                    textCell.canFocusContent = NO;
                    cell = textCell;
                    break;
                }
                case 1:
                {
#if TARGET_OS_IOS
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil)
                    {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell setCellDataWithLabelString:NSLocalizedString(@"Deinterlace",nil)
                                                 withState:[[defaults objectForKey:kVLCSettingDeinterlace] boolValue]
                                                    andTag:TAG_DEINTERLACE];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
#elif TARGET_OS_TV
                    NSInteger selectedIndex;
                    
                    SegCtrlCell *segCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedCellIdentifier];
                    if (segCtrlCell == nil)
                    {
                        segCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:SegmentedCellIdentifier
                                                               withItems:[NSArray arrayWithObjects:
                                                                          NSLocalizedString(@"Yes",nil),
                                                                          NSLocalizedString(@"No",nil),
                                                                          nil]];
                    }
                    
                    if ([[defaults objectForKey:kVLCSettingDeinterlace] boolValue])
                    {
                        selectedIndex = 0;
                    }
                    else
                    {
                        selectedIndex = 1;
                    }
                    
                    [segCtrlCell setCellDataWithLabelString:NSLocalizedString(@"Deinterlace",nil)
                                          withSelectedIndex:selectedIndex
                                                     andTag:TAG_DEINTERLACE];
                    
                    cell = segCtrlCell;
#endif
                    break;
                }
                default:
                {
                    break;
                }
            }
            break;
        }
#if TARGET_OS_IOS
        case SETTINGS_SUBTITLES_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    TextCell *textCell = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCell == nil)
                    {
                        textCell = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:TextCellIdentifier];
                    }
                    [textCell setCellDataWithLabelString:NSLocalizedString(@"Font", nil)
                                                withText:[self.fontNames objectAtIndex:self.fontIndex]
                                         withPlaceHolder:nil
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeDefault
                                            withDelegate:nil
                                                  andTag:-1];
                    textCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    textCell.textField.enabled = NO;
                    textCell.canFocusContent = NO;
                    cell = textCell;
                    break;
                }
                case 1:
                {
                    TextCell *textCell = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCell == nil)
                    {
                        textCell = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:TextCellIdentifier];
                    }
                    [textCell setCellDataWithLabelString:NSLocalizedString(@"Relative font size", nil)
                                                withText:[self.fontSizeNames objectAtIndex:self.fontSizeIndex]
                                         withPlaceHolder:nil
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeDefault
                                            withDelegate:nil
                                                  andTag:-1];
                    textCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    textCell.textField.enabled = NO;
                    textCell.canFocusContent = NO;
                    cell = textCell;
                    break;
                }
                case 2:
                {
#if TARGET_OS_IOS
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil)
                    {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell setCellDataWithLabelString:NSLocalizedString(@"Use Bold font",nil)
                                                 withState:[[defaults objectForKey:kVLCSettingSubtitlesBoldFont] boolValue]
                                                    andTag:TAG_FONT_BOLD];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
#elif TARGET_OS_TV
                    NSInteger selectedIndex;
                    
                    SegCtrlCell *segCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedCellIdentifier];
                    if (segCtrlCell == nil)
                    {
                        segCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:SegmentedCellIdentifier
                                                               withItems:[NSArray arrayWithObjects:
                                                                          NSLocalizedString(@"Yes",nil),
                                                                          NSLocalizedString(@"No",nil),
                                                                          nil]];
                    }
                    
                    if ([[defaults objectForKey:kVLCSettingSubtitlesBoldFont] boolValue])
                    {
                        selectedIndex = 0;
                    }
                    else
                    {
                        selectedIndex = 1;
                    }
                    
                    [segCtrlCell setCellDataWithLabelString:NSLocalizedString(@"Use Bold font",nil)
                                          withSelectedIndex:selectedIndex
                                                     andTag:TAG_FONT_BOLD];
                    
                    cell = segCtrlCell;
#endif
                    break;
                }
                case 3:
                {
                    TextCell *textCell = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCell == nil)
                    {
                        textCell = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:TextCellIdentifier];
                    }
                    [textCell setCellDataWithLabelString:NSLocalizedString(@"Font color", nil)
                                                withText:[self.fontColorNames objectAtIndex:self.fontColorIndex]
                                         withPlaceHolder:nil
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeDefault
                                            withDelegate:nil
                                                  andTag:-1];
                    textCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    textCell.textField.enabled = NO;
                    textCell.canFocusContent = NO;
                    cell = textCell;
                    break;
                }
                case 4:
                {
                    TextCell *textCell = (TextCell *)[tableView dequeueReusableCellWithIdentifier:TextCellIdentifier];
                    if (textCell == nil)
                    {
                        textCell = [[TextCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:TextCellIdentifier];
                    }
                    [textCell setCellDataWithLabelString:NSLocalizedString(@"Text Encoding", nil)
                                                withText:[self.textEncodingNames objectAtIndex:self.textEncodingIndex]
                                         withPlaceHolder:nil
                                                isSecure:NO
                                        withKeyboardType:UIKeyboardTypeDefault
                                            withDelegate:nil
                                                  andTag:-1];
                    textCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    textCell.textField.enabled = NO;
                    textCell.canFocusContent = NO;
                    cell = textCell;
                    break;
                }
                default:
                {
                    break;
                }
            }
            break;
        }
#endif
        case SETTINGS_AUDIO_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
#if TARGET_OS_IOS
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil)
                    {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell setCellDataWithLabelString:NSLocalizedString(@"Time-stretching audio",nil)
                                                 withState:[[defaults objectForKey:kVLCSettingStretchAudio] boolValue]
                                                    andTag:TAG_AUDIO_STRETCHING];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
#elif TARGET_OS_TV
                    NSInteger selectedIndex;
                    
                    SegCtrlCell *segCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedCellIdentifier];
                    if (segCtrlCell == nil)
                    {
                        segCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:SegmentedCellIdentifier
                                                               withItems:[NSArray arrayWithObjects:
                                                                          NSLocalizedString(@"Yes",nil),
                                                                          NSLocalizedString(@"No",nil),
                                                                          nil]];
                    }
                    
                    if ([[defaults objectForKey:kVLCSettingStretchAudio] boolValue])
                    {
                        selectedIndex = 0;
                    }
                    else
                    {
                        selectedIndex = 1;
                    }
                    
                    [segCtrlCell setCellDataWithLabelString:NSLocalizedString(@"Time-stretching audio",nil)
                                          withSelectedIndex:selectedIndex
                                                     andTag:TAG_AUDIO_STRETCHING];
                    
                    cell = segCtrlCell;
#endif
                    break;
                }
                case 1:
                {
#if TARGET_OS_IOS
                    SwitchCell *switchCell = (SwitchCell *)[tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (switchCell == nil)
                    {
                        switchCell = [[SwitchCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                       reuseIdentifier:SwitchCellIdentifier];
                    }
                    [switchCell setCellDataWithLabelString:NSLocalizedString(@"Audio playback in background",nil)
                                                 withState:[[defaults objectForKey:kVLCSettingContinueAudioInBackgroundKey] boolValue]
                                                    andTag:TAG_AUDIO_BACKGROUND];
                    [switchCell.switchButton addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
                    cell = switchCell;
#elif TARGET_OS_TV
                    NSInteger selectedIndex;
                    
                    SegCtrlCell *segCtrlCell = (SegCtrlCell *)[tableView dequeueReusableCellWithIdentifier:SegmentedCellIdentifier];
                    if (segCtrlCell == nil)
                    {
                        segCtrlCell = [[SegCtrlCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                         reuseIdentifier:SegmentedCellIdentifier
                                                               withItems:[NSArray arrayWithObjects:
                                                                          NSLocalizedString(@"Yes",nil),
                                                                          NSLocalizedString(@"No",nil),
                                                                          nil]];
                    }
                    
                    if ([[defaults objectForKey:kVLCSettingContinueAudioInBackgroundKey] boolValue])
                    {
                        selectedIndex = 0;
                    }
                    else
                    {
                        selectedIndex = 1;
                    }
                    
                    [segCtrlCell setCellDataWithLabelString:NSLocalizedString(@"Audio playback in background",nil)
                                          withSelectedIndex:selectedIndex
                                                     andTag:TAG_AUDIO_BACKGROUND];
                    
                    cell = segCtrlCell;
#endif
                    break;
                }
                default:
                {
                    break;
                }
            }
            break;
        }
        default:
        {
            break;
        }
    }
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
#if TARGET_OS_TV
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
#endif

    switch (indexPath.section)
    {
        case SETTINGS_GENERIC_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    TableSelectViewController *tableSelectViewController;
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStylePlain];
                    }
                    else
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStyleGrouped];
                    }
                    tableSelectViewController.elements = self.cachingNames;
                    tableSelectViewController.selectedElement = self.cachingIndex;
                    tableSelectViewController.delegate = self;
                    tableSelectViewController.tag = TAG_CACHING;
                    
                    [self.navigationController pushViewController:tableSelectViewController animated:YES];
                    break;
                }
            }
            break;
        }
        case SETTINGS_VIDEO_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    TableSelectViewController *tableSelectViewController;
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStylePlain];
                    }
                    else
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStyleGrouped];
                    }
                    tableSelectViewController.elements = self.skipLoopValues;
                    tableSelectViewController.selectedElement = self.skipLoopIndex;
                    tableSelectViewController.delegate = self;
                    tableSelectViewController.tag = TAG_SKIPLOOPFILTER;
                    
                    [self.navigationController pushViewController:tableSelectViewController animated:YES];
                    break;
                }
#if TARGET_OS_TV
                case 1:
                {
                    [defaults setObject:[NSNumber numberWithBool:![[defaults objectForKey:kVLCSettingDeinterlace] boolValue]]
                                 forKey:kVLCSettingDeinterlace];
                    [self.tableView reloadData];
                    break;
                }
#endif
            }
            break;
        }
#if TARGET_OS_IOS
        case SETTINGS_SUBTITLES_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    TableSelectViewController *tableSelectViewController;
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStylePlain];
                    }
                    else
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStyleGrouped];
                    }
                    tableSelectViewController.elements = self.fontNames;
                    tableSelectViewController.selectedElement = self.fontIndex;
                    tableSelectViewController.delegate = self;
                    tableSelectViewController.tag = TAG_FONT_NAME;
                    
                    [self.navigationController pushViewController:tableSelectViewController animated:YES];
                    break;
                }
                case 1:
                {
                    TableSelectViewController *tableSelectViewController;
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStylePlain];
                    }
                    else
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStyleGrouped];
                    }
                    tableSelectViewController.elements = self.fontSizeNames;
                    tableSelectViewController.selectedElement = self.fontSizeIndex;
                    tableSelectViewController.delegate = self;
                    tableSelectViewController.tag = TAG_FONT_SIZE;
                    
                    [self.navigationController pushViewController:tableSelectViewController animated:YES];
                    break;
                }
#if TARGET_OS_TV
                case 2:
                {
                    [defaults setObject:[NSNumber numberWithBool:![[defaults objectForKey:kVLCSettingSubtitlesBoldFont] boolValue]]
                                 forKey:kVLCSettingSubtitlesBoldFont];
                    [self.tableView reloadData];
                    break;
                }
#endif
                case 3:
                {
                    TableSelectViewController *tableSelectViewController;
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStylePlain];
                    }
                    else
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStyleGrouped];
                    }
                    tableSelectViewController.elements = self.fontColorNames;
                    tableSelectViewController.selectedElement = self.fontColorIndex;
                    tableSelectViewController.delegate = self;
                    tableSelectViewController.tag = TAG_FONT_COLOR;
                    
                    [self.navigationController pushViewController:tableSelectViewController animated:YES];
                    break;
                }
                case 4:
                {
                    TableSelectViewController *tableSelectViewController;
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStylePlain];
                    }
                    else
                    {
                        tableSelectViewController = [[TableSelectViewController alloc] initWithStyle:UITableViewStyleGrouped];
                    }
                    tableSelectViewController.elements = self.textEncodingNames;
                    tableSelectViewController.selectedElement = self.textEncodingIndex;
                    tableSelectViewController.delegate = self;
                    tableSelectViewController.tag = TAG_TEXT_ENCODING;
                    
                    [self.navigationController pushViewController:tableSelectViewController animated:YES];
                    break;
                }
            }
            break;
        }
#endif
#if TARGET_OS_TV
        case SETTINGS_AUDIO_SECTION_INDEX:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    [defaults setObject:[NSNumber numberWithBool:![[defaults objectForKey:kVLCSettingStretchAudio] boolValue]]
                                 forKey:kVLCSettingStretchAudio];
                    [self.tableView reloadData];
                    break;
                }
                case 1:
                {
                    [defaults setObject:[NSNumber numberWithBool:![[defaults objectForKey:kVLCSettingContinueAudioInBackgroundKey] boolValue]]
                                 forKey:kVLCSettingContinueAudioInBackgroundKey];
                    [self.tableView reloadData];
                    break;
                }
            }
            break;
        }
#endif
        default:
        {
            break;
        }
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#if TARGET_OS_IOS
- (void)switchValueChanged:(id)sender
{
	NSInteger tag = ((UISwitch *)sender).tag;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];

	switch (tag)
    {
		case TAG_DEINTERLACE:
        {
            [defaults setObject:[NSNumber numberWithBool:[sender isOn]]
                         forKey:kVLCSettingDeinterlace];
			break;
        }
        case TAG_FONT_BOLD:
        {
            [defaults setObject:[NSNumber numberWithBool:[sender isOn]]
                         forKey:kVLCSettingSubtitlesBoldFont];
            break;
        }
        case TAG_AUDIO_STRETCHING:
        {
            [defaults setObject:[sender isOn]?@"1":@"0"
                         forKey:kVLCSettingStretchAudio];
            break;
        }
        case TAG_AUDIO_BACKGROUND:
        {
            [defaults setObject:[NSNumber numberWithBool:[sender isOn]]
                         forKey:kVLCSettingContinueAudioInBackgroundKey];
            break;
        }
	}
    [defaults synchronize];
    [self.tableView reloadData];
}
#endif

- (void)selectedElementIndex:(NSInteger)elementIndex forTag:(NSInteger)tag
{
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];

	switch (tag)
    {
        case TAG_CACHING:
        {
            self.cachingIndex = elementIndex;
            [defaults setObject:[self.cachingValues objectAtIndex:elementIndex]
                         forKey:kVLCSettingNetworkCaching];
            break;
        }
        case TAG_SKIPLOOPFILTER:
        {
            self.skipLoopIndex = elementIndex;
            switch (elementIndex)
            {
                case 0:
                {
                    [defaults setObject:kVLCSettingSkipLoopFilterNone
                                 forKey:kVLCSettingSkipLoopFilter];
                    break;
                }
                case 1:
                {
                    [defaults setObject:kVLCSettingSkipLoopFilterNonRef
                                 forKey:kVLCSettingSkipLoopFilter];
                    break;
                }
                case 2:
                {
                    [defaults setObject:kVLCSettingSkipLoopFilterNonKey
                                 forKey:kVLCSettingSkipLoopFilter];
                    break;
                }
                default:
                {
                    break;
                }
            }
            break;
        }
        case TAG_FONT_NAME:
        {
            self.fontIndex = elementIndex;
            [defaults setObject:[self.fontValues objectAtIndex:elementIndex]
                         forKey:kVLCSettingSubtitlesFont];
            break;
        }
        case TAG_FONT_SIZE:
        {
            self.fontSizeIndex = elementIndex;
            [defaults setObject:[self.fontSizeValues objectAtIndex:elementIndex]
                         forKey:kVLCSettingSubtitlesFontSize];
            break;
        }
        case TAG_FONT_COLOR:
        {
            self.fontColorIndex = elementIndex;
            [defaults setObject:[self.fontColorValues objectAtIndex:elementIndex]
                         forKey:kVLCSettingSubtitlesFontColor];
            break;
        }
        case TAG_TEXT_ENCODING:
        {
            self.textEncodingIndex = elementIndex;
            [defaults setObject:[self.textEncodingValues objectAtIndex:elementIndex]
                         forKey:kVLCSettingTextEncoding];
            break;
        }
    }
    [defaults synchronize];
    [self.tableView reloadData];
}

@end
