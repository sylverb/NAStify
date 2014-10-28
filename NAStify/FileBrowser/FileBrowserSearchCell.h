//
//  FileBrowserSearchCell.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FileItem.h"

#define TAG_TEXTFIELD_CREATE_FOLDER 0
#define TAG_TEXTFIELD_FILENAME      1

@interface FileBrowserSearchCell : UITableViewCell

@property(nonatomic, strong) NSString * oldName;
@property(nonatomic, strong) UITextField * nameLabel;
@property(nonatomic, strong) UILabel * pathLabel;
@property(nonatomic, strong) UILabel * sizeLabel;
@property(nonatomic, strong) UIImageView * fileTypeImage;

- (void)setFileItem:(FileItem *)fileItem withDelegate:(id)delegate andTag:(NSInteger)tag;
- (void)setEditable;
- (void)setUneditable;

@end
