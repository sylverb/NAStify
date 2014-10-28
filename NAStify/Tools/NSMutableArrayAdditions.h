//
//  NSMutableArrayAdditions.h
//  NAStify
//
//  Created by Sylver Bruneau on 19/08/12.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableArray (NSMutableArrayAdditions)

/* enumeration of file types */
typedef enum {
	SORT_BY_NAME_DESC_FOLDER_FIRST = 0,
	SORT_BY_NAME_DESC,
	SORT_BY_NAME_ASC_FOLDER_FIRST,
	SORT_BY_NAME_ASC,
	SORT_BY_DATE_DESC_FOLDER_FIRST,
	SORT_BY_DATE_DESC,
	SORT_BY_DATE_ASC_FOLDER_FIRST,
	SORT_BY_DATE_ASC,
	SORT_BY_TYPE_DESC_FOLDER_FIRST,
	SORT_BY_TYPE_DESC,
	SORT_BY_TYPE_ASC_FOLDER_FIRST,
	SORT_BY_TYPE_ASC,
	SORT_BY_SIZE_DESC_FOLDER_FIRST,
	SORT_BY_SIZE_DESC,
	SORT_BY_SIZE_ASC_FOLDER_FIRST,
	SORT_BY_SIZE_ASC
} FileItemSortType;

- (void)sortFileItemArrayWithOrder:(FileItemSortType)sortType;

@end
