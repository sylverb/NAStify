//
//  FileItem.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

typedef enum _FILETYPE
{
	FILETYPE_FOLDER,
	FILETYPE_ARCHIVE,
    FILETYPE_QT_VIDEO,
    FILETYPE_QT_AUDIO,
    FILETYPE_VLC_AUDIO,
    FILETYPE_VLC_VIDEO,
    FILETYPE_PHOTO,
    FILETYPE_PDF,
    FILETYPE_TEXT,
	FILETYPE_UNKNOWN,
} FILETYPE;

#define kRootID @"-1"
@interface FileItem : NSObject

@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *shortPath;
@property(nonatomic, strong) NSString *path;
@property(nonatomic, strong) NSString *fullPath;
@property(nonatomic, strong) NSString *type;
@property(nonatomic, strong) NSString *fileSize;
@property(nonatomic, strong) NSNumber *fileSizeNumber;
@property(nonatomic, strong) NSString *fileDate;
@property(nonatomic, strong) NSNumber *fileDateNumber;
@property(nonatomic, strong) NSString *owner;
@property(nonatomic, strong) NSString *ejectName;
@property(nonatomic, strong) NSArray *objectIds;
@property(nonatomic) BOOL isCompressed;
@property(nonatomic) BOOL isDir;
@property(nonatomic) BOOL isEjectable;
@property(nonatomic) BOOL writeAccess;

/* get file type */
- (FILETYPE) fileType;

/* get UIImage for file type */
- (UIImage *)image;

@end
