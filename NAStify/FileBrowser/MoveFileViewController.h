//
//  MoveFileViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ConnectionManager.h"
#import "FileItem.h"

#define TAG_ALERT_CREATE_FOLDER 0

@protocol MoveFileViewDelegate
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
@optional
- (void)backFromModalView:(BOOL)refreshList;
@end

@interface MoveFileViewController : UIViewController <CMDelegate,UIAlertViewDelegate,UITableViewDataSource,UITableViewDelegate>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) id <CM> connectionManager;

@property(nonatomic, strong) UserAccount *userAccount;

@property(nonatomic, strong) FileItem *currentFolder;

@property(nonatomic, strong) NSMutableArray *folderArray;
@property(nonatomic, strong) NSArray *filesToMove;
@property(nonatomic, strong) id delegate;
@property(nonatomic, strong) UIBarButtonItem *mvButtonItem;
@property(nonatomic, strong) UIBarButtonItem *cpButtonItem;

- (void)CMFilesList:(NSDictionary *)dict;
- (void)CMCreateFolder:(NSDictionary *)dict;

@end
