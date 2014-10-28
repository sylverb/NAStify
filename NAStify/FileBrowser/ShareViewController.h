//
//  ShareViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ConnectionManager.h"
#import "FileItem.h"
#import "FolderBrowserViewController.h"
#import "TableSelectViewController.h"

@protocol ShareViewDelegate
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password;
@optional
- (void)backFromModalView:(BOOL)refreshList;
@end

@interface ShareViewController : UIViewController <UITextFieldDelegate,UITableViewDataSource,UITableViewDelegate,TableSelectViewControllerDelegate>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) id <CM> connectionManager;
@property(nonatomic, strong) NSArray *files;
@property(nonatomic, strong) NSString *password;
@property(nonatomic) NSTimeInterval duration;
@property(nonatomic, strong) id delegate;

@property(nonatomic, strong) NSArray *shareValidityOptions;
@property(nonatomic, strong) NSMutableArray *shareValidityValues;
@property(nonatomic) NSInteger shareValidityIndex;

@property (nonatomic, strong) UIPopoverController *destPopoverController;

@end
