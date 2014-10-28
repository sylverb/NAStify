//
//  FolderBrowserViewController.h
//  Synology DS
//
//  Created by Sylver Bruneau on 19/05/11.
//  Copyright 2011 Sylver Bruneau. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ConnectionManager.h"

@protocol FolderBrowserViewControllerDelegate
- (void)selectedFolderAtPath:(FileItem *)folder andTag:(NSInteger)tag;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
@end

@interface FolderBrowserViewController : UIViewController <CMDelegate,UIAlertViewDelegate,UITableViewDataSource,UITableViewDelegate>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) id <CM> connectionManager;
@property(nonatomic) NSInteger tag;
@property(nonatomic, strong) NSMutableArray *folderArray;
@property(nonatomic, strong) FileItem *currentFolder;
@property(nonatomic, strong) id<FolderBrowserViewControllerDelegate> delegate;

- (id)initWithPath:(FileItem *)folder;

- (void)CMFilesList:(NSDictionary *)dict;
- (void)CMCreateFolder:(NSDictionary *)dict;

@end

