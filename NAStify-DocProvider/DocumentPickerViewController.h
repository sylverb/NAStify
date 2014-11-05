//
//  DocumentPickerViewController.h
//  NAStify-
//
//  Created by Sylver Bruneau on 11/10/2014.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LTHPasscodeViewController.h"
#import <DropboxSDK/DropboxSDK.h>

typedef enum {
    ProviderModeImport,
    ProviderModeExport
} ProviderMode;

@interface DocumentPickerViewController : UIDocumentPickerExtensionViewController <DBSessionDelegate, LTHPasscodeViewControllerDelegate>

@property(nonatomic,retain) UINavigationController *nc;
@property(nonatomic) ProviderMode mode;
@property (strong, nonatomic) NSString *relinkUserId; // Dropbox relink handling

- (void)openDocument:(NSString *)path;
- (void)uploadFinished;

@end
