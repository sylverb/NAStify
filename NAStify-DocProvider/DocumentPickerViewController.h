//
//  DocumentPickerViewController.h
//  NAStify-
//
//  Created by Sylver Bruneau on 11/10/2014.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DropboxSDK/DropboxSDK.h>

@interface DocumentPickerViewController : UIDocumentPickerExtensionViewController <DBSessionDelegate>

@property(nonatomic,retain) UINavigationController *nc;

- (void)openDocument:(NSString *)path;
- (void)uploadFinished;

@property (strong, nonatomic) NSString *relinkUserId; // Dropbox relink handling

@end
