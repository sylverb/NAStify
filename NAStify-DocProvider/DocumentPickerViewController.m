//
//  DocumentPickerViewController.m
//  NAStify-
//
//  Created by Sylver Bruneau on 11/10/2014.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "DocumentPickerViewController.h"
#import "FileProviderViewController.h"
#import "SSKeychain.h"
#import "LTHPasscodeViewController.h"
#import "private.h"

@implementation DocumentPickerViewController

- (void)openDocument:(NSString *)path {
    NSURL *documentURL = [NSURL fileURLWithPath:path];
    NSFileManager *manager = [NSFileManager defaultManager];
    
    if (![manager fileExistsAtPath:[documentURL path]]) {
        return;
    }

    NSDictionary *atributes;
    
    [atributes setValue:[NSString stringWithFormat:@"%d", 0777]
                 forKey:NSFilePosixPermissions];
    NSError *error;
    [manager setAttributes:atributes ofItemAtPath:path error:&error];
    
    if (self.nc)
    {
        [self.nc dismissViewControllerAnimated:YES completion:nil];
    }
    [self dismissGrantingAccessToURL:documentURL];
}

- (void)uploadFinished {
    if (self.nc)
    {
        [self.nc dismissViewControllerAnimated:YES completion:nil];
    }
    [self dismissGrantingAccessToURL:nil];
}

-(void)prepareForPresentationInMode:(UIDocumentPickerMode)mode {
    // Show Passkey if needed
    if ([LTHPasscodeViewController doesPasscodeExist])
    {
        [[LTHPasscodeViewController sharedUser] showLockScreenWithAnimation:YES withLogout:NO andLogoutTitle:nil];
    }

    // Prepare "File Provider Storage" folder (delete previous one and create it again to clean it)
    NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
    NSString *storageFolderPath = [containerURL.path stringByAppendingString:@"/File Provider Storage"];
    
    [[NSFileManager defaultManager] removeItemAtPath:storageFolderPath error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:storageFolderPath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL];
    
    // Initialize Dropbox settings
    // Dropbox init
    NSString* appKey = DROPBOX_APPKEY;
    NSString* appSecret = DROPBOX_APPSECRET;
    NSString *root = kDBRootDropbox; // Should be set to either kDBRootAppFolder or kDBRootDropbox
    
    DBSession* session = [[DBSession alloc] initWithAppKey:appKey appSecret:appSecret root:root];
    [DBSession setSharedSession:session];

    // Show menu
    switch (mode)
    {
        case UIDocumentPickerModeImport:
        {
            FileProviderViewController *vc = [[FileProviderViewController alloc] init];
            vc.delegate = self;
            vc.validTypes = self.validTypes;
            vc.mode = ProviderModeImport;
            self.nc = [[UINavigationController alloc] initWithRootViewController:vc];
            [self presentViewController:self.nc
                               animated:YES
                             completion:nil];
            break;
        }
        case UIDocumentPickerModeExportToService:
        {
            FileProviderViewController *vc = [[FileProviderViewController alloc] init];
            vc.delegate = self;
            vc.validTypes = self.validTypes;
            vc.mode = ProviderModeExport;
            vc.fileURL = self.originalURL;
            self.nc = [[UINavigationController alloc] initWithRootViewController:vc];
            [self presentViewController:self.nc
                               animated:YES
                             completion:nil];
        }
        default:
            break;
    }
}

#pragma mark - DBSessionDelegate methods

- (void)sessionDidReceiveAuthorizationFailure:(DBSession*)session userId:(NSString *)userId
{
    self.relinkUserId = userId;
    
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"Dropbox Session Ended",nil)
                                message:NSLocalizedString(@"Do you want to relink?",nil)
                                preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *relink = [UIAlertAction actionWithTitle:NSLocalizedString(@"Relink",nil)
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction * action) {
                                                       [[DBSession sharedSession] linkUserId:self.relinkUserId fromController:self.tabBarController];
                                                       self.relinkUserId = nil;
                                                       [alert dismissViewControllerAnimated:YES completion:nil];
                                                   }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel",nil)
                                                     style:UIAlertActionStyleCancel
                                                   handler:^(UIAlertAction * action) {
                                                       [alert dismissViewControllerAnimated:YES completion:nil];
                                                   }];
    
    [alert addAction:relink];
    [alert addAction:cancel];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
