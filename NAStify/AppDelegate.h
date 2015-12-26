//
//  AppDelegate.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CustomTabBarController.h"
#import "ServersListViewController.h"
#import <DropboxSDK/DropboxSDK.h>
#import "VLCPlayerDisplayController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate,DBSessionDelegate,UIAlertViewDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) CustomTabBarController *tabBarController;
@property (strong, nonatomic) UINavigationController *serversNavController;
@property (strong, nonatomic) UINavigationController *fileBrowserNavController;
@property (strong, nonatomic) UINavigationController *settingsNavController;

@property (strong, nonatomic) NSString *relinkUserId; // Dropbox relink handling

@end
