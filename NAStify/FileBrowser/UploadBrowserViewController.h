//
//  UploadBrowserViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ConnectionManager.h"

@protocol UploadBrowserViewControllerDelegate
- (void)uploadFile:(FileItem *)file;
@end

@interface UploadBrowserViewController : UIViewController <CMDelegate,UIAlertViewDelegate,UITableViewDataSource,UITableViewDelegate>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) id <CM> connectionManager;
@property(nonatomic) NSInteger tag;
@property(nonatomic, strong) NSMutableArray *filesArray;
@property(nonatomic, strong) FileItem *currentFolder;
@property(nonatomic, strong) id<UploadBrowserViewControllerDelegate> delegate;

- (void)CMFilesList:(NSDictionary *)dict;

@end

