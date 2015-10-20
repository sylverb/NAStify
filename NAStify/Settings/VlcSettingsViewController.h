//
//  VlcSettingsViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TableSelectViewController.h"

@interface VlcSettingsViewController : UITableViewController <TableSelectViewControllerDelegate>

// libVLC settings
@property (nonatomic, strong) NSArray *cachingValues;
@property (nonatomic, strong) NSArray *cachingNames;
@property (nonatomic) NSInteger cachingIndex;
@property (nonatomic, strong) NSArray *skipLoopValues;
@property (nonatomic) NSInteger skipLoopIndex;
@property (nonatomic, strong) NSArray *fontValues;
@property (nonatomic, strong) NSArray *fontNames;
@property (nonatomic) NSInteger fontIndex;
@property (nonatomic, strong) NSArray *fontSizeValues;
@property (nonatomic, strong) NSArray *fontSizeNames;
@property (nonatomic) NSInteger fontSizeIndex;
@property (nonatomic, strong) NSArray *fontColorValues;
@property (nonatomic, strong) NSArray *fontColorNames;
@property (nonatomic) NSInteger fontColorIndex;
@property (nonatomic, strong) NSArray *textEncodingValues;
@property (nonatomic, strong) NSArray *textEncodingNames;
@property (nonatomic) NSInteger textEncodingIndex;

@end
