//
//  AppDelegate.m
//  NAStify-tvOS
//
//  Created by Sylver B on 27/09/15.
//  Copyright © 2015 Sylver B. All rights reserved.
//

#import "TVAppDelegate.h"
#import "VLCPlayerDisplayController.h"
#import "SettingsViewController.h"
#import "NAStifyAboutViewController.h"
#import "MetaDataFetcherKit.h"
#import "private.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

+ (void)initialize
{
    // Set default values
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    
    NSDictionary *appDefaults = @{kVLCSettingContinueAudioInBackgroundKey : @(YES),
                                  kVLCSettingStretchAudio : @(NO),
                                  kVLCSettingVideoFullscreenPlayback : @(NO),
                                  kVLCSettingTextEncoding : kVLCSettingTextEncodingDefaultValue,
                                  kVLCSettingSkipLoopFilter : kVLCSettingSkipLoopFilterNonRef,
                                  kVLCSettingSubtitlesFont : kVLCSettingSubtitlesFontDefaultValue,
                                  kVLCSettingSubtitlesFontColor : kVLCSettingSubtitlesFontColorDefaultValue,
                                  kVLCSettingSubtitlesFontSize : kVLCSettingSubtitlesFontSizeDefaultValue,
                                  kVLCSettingSubtitlesBoldFont: kVLCSettingSubtitlesBoldFontDefaultValue,
                                  kVLCSettingDeinterlace : kVLCSettingDeinterlaceDefaultValue,
                                  kVLCSettingNetworkCaching : kVLCSettingNetworkCachingDefaultValue,
                                  kVLCSettingEqualizerProfile : kVLCSettingEqualizerProfileDefaultValue,
                                  kVLCSettingPlaybackForwardSkipLength : kVLCSettingPlaybackForwardSkipLengthDefaultValue,
                                  kVLCSettingPlaybackBackwardSkipLength : kVLCSettingPlaybackBackwardSkipLengthDefaultValue,
                                  kNASTifySettingPlayerType : @(kNASTifySettingPlayerTypeInternal),
                                  kNASTifySettingInternalPlayer : @(kNASTifySettingInternalPlayerTypeVLCOnly),
                                  kNASTifySettingBrowserType : @(kNASTifySettingBrowserTypeGrid),
                                  kNASTifySettingAllowDelete : @(NO)};

    [defaults registerDefaults:appDefaults];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#ifndef DEBUG
   [Fabric with:@[[Crashlytics class]]];
#endif
    // Application launching
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    ServersListViewController *userAccountsViewController = [[ServersListViewController alloc] init];
    self.serversNavController = [[UINavigationController alloc] initWithRootViewController:userAccountsViewController];
    self.serversNavController.title = NSLocalizedString(@"Servers",nil);

    TVFavoritesListViewController *favoritesViewController = [[TVFavoritesListViewController alloc] init];
    self.favoritesNavController = [[UINavigationController alloc] initWithRootViewController:favoritesViewController];
    self.favoritesNavController.title = NSLocalizedString(@"Favorites",nil);

    SettingsViewController *settingsViewController = [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    self.settingsNavController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    self.settingsNavController.title = NSLocalizedString(@"Settings",nil);

    NAStifyAboutViewController *aboutController = [[NAStifyAboutViewController alloc] init];
    UINavigationController *aboutNavController = [[UINavigationController alloc] initWithRootViewController:aboutController];
    aboutNavController.title = NSLocalizedString(@"About",nil);
    
    NSArray *navControllersArray = [NSArray arrayWithObjects:
                                    self.serversNavController,
                                    self.favoritesNavController,
                                    self.settingsNavController,
                                    aboutNavController,
                                    nil];
    self.tabBarController = [[UITabBarController alloc] init];
    self.tabBarController.viewControllers = navControllersArray;
    
    // Set root view controller
    VLCPlayerDisplayController *playerDisplayController = [VLCPlayerDisplayController sharedInstance];
    playerDisplayController.childViewController = self.tabBarController;
    self.window.rootViewController = playerDisplayController;
    
    [self.window makeKeyAndVisible];

    // Init
    MDFMovieDBSessionManager *movieDBSessionManager = [MDFMovieDBSessionManager sharedInstance];
    movieDBSessionManager.apiKey = TMDB_API_KEY;
    [movieDBSessionManager fetchProperties];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
