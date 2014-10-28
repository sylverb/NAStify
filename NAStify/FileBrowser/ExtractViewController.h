//
//  ExtractViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ConnectionManager.h"
#import "FileItem.h"
#import "FolderBrowserViewController.h"

@protocol ExtractViewDelegate
- (void)extractFiles:(NSArray *)files toFolder:(FileItem *)folder withPassword:(NSString *)password overwrite:(BOOL)overwrite extractWithFolder:(BOOL)extractFolders;
@optional
- (void)backFromModalView:(BOOL)refreshList;
@end

@interface ExtractViewController : UIViewController <UITextFieldDelegate,FolderBrowserViewControllerDelegate,UITableViewDataSource,UITableViewDelegate>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) id <CM> connectionManager;
@property(nonatomic, strong) NSMutableArray *folderArray;
@property(nonatomic, strong) NSArray *files;
@property(nonatomic, strong) FileItem *destFolder;
@property(nonatomic, strong) NSString *password;
@property(nonatomic, strong) id delegate;
@property(nonatomic) BOOL overwrite;
@property(nonatomic) BOOL extractWithFolders;

@property (nonatomic, strong) UIPopoverController *destPopoverController;

@end
