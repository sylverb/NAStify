//
//  FileBrowserCell.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FileItem.h"

#define TAG_TEXTFIELD_CREATE_FOLDER 0
#define TAG_TEXTFIELD_FILENAME      1

@interface FileBrowserCell : UITableViewCell

@property(nonatomic, strong) NSString * oldName;
@property(nonatomic, strong) UITextField * nameLabel;
@property(nonatomic, strong) UILabel * dateLabel;
@property(nonatomic, strong) UILabel * sizeLabel;
@property(nonatomic, strong) UILabel * ownerLabel;
@property(nonatomic, strong) UIImageView * fileTypeImage;
@property(nonatomic, strong) UIImageView * ejectableImage;

- (void)setFileItem:(FileItem *)fileItem withDelegate:(id)delegate andTag:(NSInteger)tag;
- (void)setEditable;
- (void)setUneditable;

@end
