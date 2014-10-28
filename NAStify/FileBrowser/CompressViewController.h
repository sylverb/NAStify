//
//  CompressViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ConnectionManager.h"
#import "FolderBrowserViewController.h"
#import "TableSelectViewController.h"
#import "FileItem.h"
#import "AltTextCell.h"

@protocol CompressViewDelegate
- (void)compressFiles:(NSArray *)files toArchive:(NSString *)archive archiveType:(ARCHIVE_TYPE)archiveType compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel password:(NSString *)password overwrite:(BOOL)overwrite; // files : array of type FileItem
@optional
- (void)backFromModalView:(BOOL)refreshList;
@end

@interface CompressViewController : UIViewController <UITextFieldDelegate,FolderBrowserViewControllerDelegate,TableSelectViewControllerDelegate,UITableViewDataSource,UITableViewDelegate>

@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) id <CM> connectionManager;
@property(nonatomic, strong) NSMutableArray *folderArray;
@property(nonatomic, strong) NSString *atPath;
@property(nonatomic, strong) NSArray *files;
@property(nonatomic, strong) NSMutableArray *archiveTypes;
@property(nonatomic, strong) NSMutableArray *archiveTypeExtensions;
@property(nonatomic, strong) NSArray *compressionLevels;
@property(nonatomic, strong) FileItem *destFolder;
@property(nonatomic, strong) NSString *destArchiveName;
@property(nonatomic, strong) NSString *destArchiveExtension;
@property(nonatomic, strong) NSString *password;
@property(nonatomic, strong) id delegate;
@property(nonatomic) BOOL overwrite;
@property(nonatomic) NSInteger selectedTypeIndex;
@property(nonatomic) NSInteger selectedCompressionLevelIndex;
@property(nonatomic, strong) AltTextCell *editedCell;

@property (nonatomic, strong) UIPopoverController *destPopoverController;
@property (nonatomic, strong) UIPopoverController *archiveTypePopoverController;
@property (nonatomic, strong) UIPopoverController *compressionLevelPopoverController;

@end
