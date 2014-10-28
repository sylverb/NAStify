//
//  SortItemsViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TableSelectViewController.h"

@protocol SortItemsViewController
- (void)selectedSortingType:(FileItemSortType)sortingType;
@optional
- (void)cancelSortingType;
- (void)backFromModalView:(BOOL)refreshList;
@end

@interface SortItemsViewController : UIViewController <UITextFieldDelegate,UITableViewDataSource,UITableViewDelegate,TableSelectViewControllerDelegate>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSArray *sortingOptions;
@property(nonatomic) BOOL descending;
@property(nonatomic) BOOL foldersFirst;
@property(nonatomic) NSInteger selectedSortingOptionIndex;
@property(nonatomic, strong) id delegate;

@property (nonatomic, strong) UIPopoverController *sortingOptionPopoverController;

- (id)initWithSortingType:(FileItemSortType)sortingType;

@end
