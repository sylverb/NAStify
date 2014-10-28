//
//  TableSelectViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TableSelectViewControllerDelegate
- (void)selectedElementIndex:(NSInteger)elementIndex forTag:(NSInteger)tag;
@end

@interface TableSelectViewController : UIViewController <UITableViewDataSource,UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *elements;
@property (nonatomic) NSInteger selectedElement;
@property (nonatomic) NSInteger tag;
@property (nonatomic) UITableViewStyle style;
@property (nonatomic, strong) id<TableSelectViewControllerDelegate> delegate;

- (id)initWithStyle:(UITableViewStyle)style;

@end
