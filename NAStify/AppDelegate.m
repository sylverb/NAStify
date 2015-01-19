//
//  AppDelegate.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "AppDelegate.h"
#import "private.h"
#import "FileBrowserViewController.h"
#import "SettingsViewController.h"
#import "LTHPasscodeViewController.h"
#import "iRate.h"
#import "MKStoreKit.h"

@implementation AppDelegate

+ (void)initialize
{
    // iRate init
    [iRate sharedInstance].daysUntilPrompt = 5;
    [iRate sharedInstance].usesUntilPrompt = 15;
    [iRate sharedInstance].useAllAvailableLanguages = NO;
    [iRate sharedInstance].appStoreID = 917241569;

    // Set default values
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.sylver.NAStify"];
    
    NSNumber *skipLoopFilterDefaultValue;
    int deviceSpeedCategory = [[UIDevice currentDevice] speedCategory];
    if (deviceSpeedCategory < 3)
        skipLoopFilterDefaultValue = kVLCSettingSkipLoopFilterNonKey;
    else
        skipLoopFilterDefaultValue = kVLCSettingSkipLoopFilterNonRef;
    
    NSDictionary *appDefaults = @{kVLCSettingContinueAudioInBackgroundKey : @(YES), kVLCSettingStretchAudio : @(NO), kVLCSettingTextEncoding : kVLCSettingTextEncodingDefaultValue, kVLCSettingSkipLoopFilter : skipLoopFilterDefaultValue, kVLCSettingSubtitlesFont : kVLCSettingSubtitlesFontDefaultValue, kVLCSettingSubtitlesFontColor : kVLCSettingSubtitlesFontColorDefaultValue, kVLCSettingSubtitlesFontSize : kVLCSettingSubtitlesFontSizeDefaultValue, kVLCSettingSubtitlesBoldFont: kVLCSettingSubtitlesBoldFontDefaulValue, kVLCSettingDeinterlace : kVLCSettingDeinterlaceDefaultValue, kVLCSettingNetworkCaching : kVLCSettingNetworkCachingDefaultValue, kVLCSettingPlaybackGestures : [NSNumber numberWithBool:YES], kNASTifySettingBrowserShowGCast : @(YES), kNASTifySettingPlayerType : @(kNASTifySettingPlayerTypeInternal), kNASTifySettingInternalPlayer : @(kNASTifySettingInternalPlayerTypeQTVLC)};
    
    [defaults registerDefaults:appDefaults];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // In-App purchase management
#ifdef TEST_INAPP_PURCHASE
    NSURL *tmpcontainerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
    [[NSFileManager defaultManager] removeItemAtPath:[tmpcontainerURL.path stringByAppendingPathComponent:@"purchaserecord.plist"] error:NULL];
#endif
    [[MKStoreKit sharedKit] startProductRequest];
    
    // Dropbox init
    NSString* appKey = DROPBOX_APPKEY;
	NSString* appSecret = DROPBOX_APPSECRET;
    NSString *root = kDBRootDropbox; // Should be set to either kDBRootAppFolder or kDBRootDropbox
    
    DBSession* session = [[DBSession alloc] initWithAppKey:appKey appSecret:appSecret root:root];
    session.delegate = self; // DBSessionDelegate methods allow you to handle re-authenticating
    [DBSession setSharedSession:session];

    // StatusBar configuration
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
    
    // Application launching
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Configure application subviews
    self.tabBarController = [[CustomTabBarController alloc] init];
    
    ServersListViewController *userAccountsViewController = [[ServersListViewController alloc] init];
    self.serversNavController = [[UINavigationController alloc] initWithRootViewController:userAccountsViewController];
    self.serversNavController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Servers",nil)
                                                                         image:[UIImage imageNamed:@"network-disk.png"]
                                                                           tag:0];
    
    UserAccount *localAccount = [[UserAccount alloc] init];
    localAccount.serverType = SERVER_TYPE_LOCAL;
    
    // Create Documents folder
    NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
    NSString *incomingPath = [containerURL.path stringByAppendingString:@"/Documents/incoming/"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:incomingPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

    // Create Cache folder (used for file preview)
    NSString *cachePath = [containerURL.path stringByAppendingString:@"/Cache/"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:cachePath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

    // Init views
    FileItem *rootFolder = [[FileItem alloc] init];
    rootFolder.isDir = YES;
    rootFolder.path = @"/";
    rootFolder.fullPath = [containerURL.path stringByAppendingString:@"/Documents"];
    [[NSFileManager defaultManager] createDirectoryAtPath:rootFolder.fullPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

    FileBrowserViewController *fileBrowserViewController = [[FileBrowserViewController alloc] init];
    fileBrowserViewController.userAccount = localAccount;
    fileBrowserViewController.currentFolder =rootFolder;
    self.fileBrowserNavController = [[UINavigationController alloc] initWithRootViewController:fileBrowserViewController];
        
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        self.fileBrowserNavController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Local",nil)
                                                                                 image:[UIImage imageNamed:@"ipad.png"]
                                                                                   tag:0];
    }
    else
    {
        self.fileBrowserNavController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Local",nil)
                                                                                 image:[UIImage imageNamed:@"iphone.png"]
                                                                                   tag:0];
    }
    
    SettingsViewController *settingsViewController = [[SettingsViewController alloc] init];
    self.settingsNavController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    self.settingsNavController.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings",nil)
                                                                        image:[UIImage imageNamed:@"setup.png"]
                                                                          tag:0];

    // Set tab bar items
    NSArray *navControllersArray = [NSArray arrayWithObjects:
                                    self.serversNavController,
                                    self.fileBrowserNavController,
                                    self.settingsNavController,
                                    nil];
    self.tabBarController.viewControllers = navControllersArray;
    
    // Set root view controller
    self.window.rootViewController   = self.tabBarController;
    
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    // Show Passkey if needed
    if ([LTHPasscodeViewController doesPasscodeExist])
    {
        [[LTHPasscodeViewController sharedUser] showLockScreenWithAnimation:YES withLogout:NO andLogoutTitle:nil];
    }
    
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([[DBSession sharedSession] handleOpenURL:url])
    {
         NSString *query = url.query;
        if ([[url absoluteString] rangeOfString:@"cancel"].location == NSNotFound)
        {
            NSDictionary *urlData = [DBSession parseURLParams:query];
            NSString *uid = [urlData objectForKey:@"uid"];
            if ([[[DBSession sharedSession] userIds] containsObject:uid])
            {
                NSNotification* notification = [NSNotification notificationWithName:@"DROPBOXLINK"
                                                                             object:self
                                                                           userInfo:[NSDictionary dictionaryWithObjectsAndKeys:uid,@"userId",nil]];
                
                [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];

            }
        }
        else
        {
            // user cancelled the login
            NSNotification* notification = [NSNotification notificationWithName:@"DROPBOXLINK"
                                                                         object:self
                                                                       userInfo:nil];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
        }
        return YES;
    }
    else
    {
        // Move everything from /Inbox to /incoming and delete /Inbox
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *inboxPath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Inbox"];
        
        NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
        NSString *incomingPath = [containerURL.path stringByAppendingString:@"/Documents/incoming"];

        [[NSFileManager defaultManager] createDirectoryAtPath:incomingPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];
        
        NSArray *filesArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:inboxPath
                                                                                  error:NULL];
        for (NSString *file in filesArray)
        {
            NSString *filePath = [inboxPath stringByAppendingPathComponent:file];
            NSString *destFilePath = [incomingPath stringByAppendingPathComponent:file];
            [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:destFilePath error:NULL];
        }
        
        // Show "/incoming" folder content to user
        [self.tabBarController setSelectedIndex:1];
        [self.fileBrowserNavController popToRootViewControllerAnimated:NO];
        
        UserAccount *localAccount = [[UserAccount alloc] init];
        localAccount.serverType = SERVER_TYPE_LOCAL;
        
        FileItem *inboxFolder = [[FileItem alloc] init];
        inboxFolder.isDir = YES;
        inboxFolder.path = @"/incoming";
        inboxFolder.fullPath = incomingPath;
        
        FileBrowserViewController *fileBrowserViewController = [[FileBrowserViewController alloc] init];
        fileBrowserViewController.userAccount = localAccount;
        fileBrowserViewController.currentFolder = inboxFolder;
        
        [self.fileBrowserNavController pushViewController:fileBrowserViewController animated:NO];
    }
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Move files imported using iTunes into the Documents/incoming folder
    BOOL importedFiles = NO;
    NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
    NSString *incomingPath = [containerURL.path stringByAppendingString:@"/Documents/incoming/"];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *itunesSharePath = [paths objectAtIndex:0];
    
    NSArray *filesArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:itunesSharePath
                                                                              error:NULL];
    for (NSString *file in filesArray)
    {
        if (![file isEqualToString:@"Inbox"] &&
            ![file isEqualToString:@"Connect_SDK_Device_Store.json"])
        {
            importedFiles = YES;
            NSString *filePath = [itunesSharePath stringByAppendingPathComponent:file];
            NSString *destFilePath = [incomingPath stringByAppendingPathComponent:file];
            [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:destFilePath error:NULL];
        }
    }
    
    // Show "/incoming" folder content to user if some files have been imported
    if (importedFiles)
    {
        [self.tabBarController setSelectedIndex:1];
        [self.fileBrowserNavController popToRootViewControllerAnimated:NO];
        
        UserAccount *localAccount = [[UserAccount alloc] init];
        localAccount.serverType = SERVER_TYPE_LOCAL;
        
        FileItem *inboxFolder = [[FileItem alloc] init];
        inboxFolder.isDir = YES;
        inboxFolder.path = @"/incoming";
        inboxFolder.fullPath = incomingPath;
        
        FileBrowserViewController *fileBrowserViewController = [[FileBrowserViewController alloc] init];
        fileBrowserViewController.userAccount = localAccount;
        fileBrowserViewController.currentFolder = inboxFolder;
        
        [self.fileBrowserNavController pushViewController:fileBrowserViewController animated:NO];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - DBSessionDelegate methods

- (void)sessionDidReceiveAuthorizationFailure:(DBSession*)session userId:(NSString *)userId
{
	self.relinkUserId = userId;
	[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Dropbox Session Ended",nil)
                                message:NSLocalizedString(@"Do you want to relink?",nil)
                               delegate:self
                      cancelButtonTitle:NSLocalizedString(@"Cancel",nil)
                      otherButtonTitles:NSLocalizedString(@"Relink",nil), nil]
	 show];
}


#pragma mark - UIAlertViewDelegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index
{
	if (index != alertView.cancelButtonIndex)
    {
		[[DBSession sharedSession] linkUserId:self.relinkUserId fromController:self.tabBarController];
	}
	self.relinkUserId = nil;
}

@end
