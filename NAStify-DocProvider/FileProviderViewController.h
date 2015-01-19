//
//  FileProviderViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ServerCell.h"
#import "DocumentPickerViewController.h"
#ifdef SAMBA
#import "AFNetworking.h"
#endif
@class ConnectionManager;

@interface FileProviderViewController : UITableViewController<UITextFieldDelegate>
@property(nonatomic, strong) NSMutableArray * accounts;
@property(nonatomic, strong) DocumentPickerViewController *delegate;
@property(nonatomic, strong) NSArray *validTypes;
@property(nonatomic) ProviderMode mode;
@property(nonatomic, strong) NSURL *fileURL;
#ifdef SAMBA
@property(nonatomic, strong) AFHTTPRequestOperationManager *manager;
#endif
@end
