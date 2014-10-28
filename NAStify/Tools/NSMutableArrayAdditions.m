//
//  NSMutableArrayAdditions.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "NSMutableArrayAdditions.h"
#import "FileItem.h"

@implementation NSMutableArray (NSMutableArrayAdditions)

#pragma mark - sorting functions

static NSComparisonResult sortFilesRevertOrder(id leftArray, id rightArray, void *context) {
    return NSOrderedDescending;
}

static NSComparisonResult sortFilesByDateDesc(FileItem *firstFile, FileItem *secondFile, void *context)
{
    if ((firstFile.fileDateNumber == nil) && (secondFile.fileDateNumber == nil))
    {
        return NSOrderedSame;
    }
    else if (firstFile.fileDateNumber == nil)
    {
        return NSOrderedDescending;
    }
    else if (secondFile.fileDateNumber == nil)
    {
        return NSOrderedAscending;
    }
	NSComparisonResult result = [secondFile.fileDateNumber compare:firstFile.fileDateNumber];
	return result;
}

static NSComparisonResult sortFilesByDateAsc(FileItem *firstFile, FileItem *secondFile, void *context)
{
	NSComparisonResult result = [firstFile.fileDateNumber compare:secondFile.fileDateNumber];
	return result;
}

static NSComparisonResult sortFilesByDateFoldersFirstDesc(FileItem *firstFile, FileItem *secondFile, void *context) {
	NSComparisonResult result = NSOrderedSame;
	if ((firstFile.isDir && secondFile.isDir) ||
		(!firstFile.isDir && !secondFile.isDir)) {
		result = [secondFile.fileDateNumber compare:firstFile.fileDateNumber];
	} else if (firstFile.isDir) {
		result = NSOrderedAscending;
	} else if (secondFile.isDir) {
		result = NSOrderedDescending;
	}

	return result;
}

static NSComparisonResult sortFilesByDateFoldersFirstAsc(FileItem *firstFile, FileItem *secondFile, void *context) {
	NSComparisonResult result = NSOrderedSame;
	if ((firstFile.isDir && secondFile.isDir) ||
		(!firstFile.isDir && !secondFile.isDir)) {
		result = [firstFile.fileDateNumber compare:secondFile.fileDateNumber];
	} else if (firstFile.isDir) {
		result = NSOrderedAscending;
	} else if (secondFile.isDir) {
		result = NSOrderedDescending;
	}
    
	return result;
}

static NSComparisonResult sortFilesBySizeDesc(FileItem *firstFile, FileItem *secondFile, void *context)
{
	NSComparisonResult result = NSOrderedSame;
	if (firstFile.isDir && secondFile.isDir)
    {
        // Folders are all the same size, order them by name
		result = [firstFile.name caseInsensitiveCompare:secondFile.name];
    }
    else if (!firstFile.isDir && !secondFile.isDir)
    {
        // Comparing 2 files, order them by size
        result = [secondFile.fileSizeNumber compare:firstFile.fileSizeNumber];
	}
    // We are descending -> put the folders at the end of the list
    else if (firstFile.isDir)
    {
		result = NSOrderedDescending;
	}
    else if (secondFile.isDir)
    {
		result = NSOrderedAscending;
	}
	return result;
}

static NSComparisonResult sortFilesBySizeAsc(FileItem *firstFile, FileItem *secondFile, void *context) {
	NSComparisonResult result = NSOrderedSame;
	if (firstFile.isDir && secondFile.isDir)
    {
        // Folders are all the same size, order them by name
		result = [firstFile.name caseInsensitiveCompare:secondFile.name];
    }
    else if (!firstFile.isDir && !secondFile.isDir)
    {
        // Comparing 2 files, order them by size
        result = [firstFile.fileSizeNumber compare:secondFile.fileSizeNumber];
	}
    // We are ascending -> put the folders at the top of the list
    else if (firstFile.isDir)
    {
		result = NSOrderedAscending;
	}
    else if (secondFile.isDir)
    {
		result = NSOrderedDescending;
	}
	return result;
}

static NSComparisonResult sortFilesBySizeFoldersFirstDesc(FileItem *firstFile, FileItem *secondFile, void *context)
{
	NSComparisonResult result = NSOrderedSame;
	if (firstFile.isDir && secondFile.isDir)
    {
        // Folders are all the same size, order them by name
		result = [firstFile.name caseInsensitiveCompare:secondFile.name];
    }
    else if (!firstFile.isDir && !secondFile.isDir)
    {
        // Comparing 2 files, order them by size
        result = [secondFile.fileSizeNumber compare:firstFile.fileSizeNumber];
	}
    // put the folders at the top of the list
    else if (firstFile.isDir)
    {
		result = NSOrderedAscending;
	}
    else if (secondFile.isDir)
    {
		result = NSOrderedDescending;
	}
	return result;
}

static NSComparisonResult sortFilesBySizeFoldersFirstAsc(FileItem *firstFile, FileItem *secondFile, void *context) {
	return sortFilesBySizeAsc(firstFile, secondFile, context);
}

static NSComparisonResult sortFilesByNameFoldersFirstDesc(FileItem *firstFile, FileItem *secondFile, void *context) {
	NSComparisonResult result = NSOrderedSame;
	if ((firstFile.isDir && secondFile.isDir) ||
		(!firstFile.isDir && !secondFile.isDir)) {
		result = [firstFile.name caseInsensitiveCompare:secondFile.name];
	} else if (firstFile.isDir) {
		result = NSOrderedAscending;
	} else if (secondFile.isDir) {
		result = NSOrderedDescending;
	}
	
	return result;
}

static NSComparisonResult sortFilesByNameFoldersFirstAsc(FileItem *firstFile, FileItem *secondFile, void *context) {
	NSComparisonResult result = NSOrderedSame;
	if ((firstFile.isDir && secondFile.isDir) ||
		(!firstFile.isDir && !secondFile.isDir)) {
		result = [secondFile.name caseInsensitiveCompare:firstFile.name];
	} else if (firstFile.isDir) {
		result = NSOrderedAscending;
	} else if (secondFile.isDir) {
		result = NSOrderedDescending;
	}
	
	return result;
}

static NSComparisonResult sortFilesByNameDesc(FileItem *firstFile, FileItem *secondFile, void *context) {
	NSComparisonResult result = NSOrderedSame;
	result = [firstFile.name caseInsensitiveCompare:secondFile.name];
	
	return result;
}

static NSComparisonResult sortFilesByNameAsc(FileItem *firstFile, FileItem *secondFile, void *context) {
	NSComparisonResult result = NSOrderedSame;
	result = [secondFile.name caseInsensitiveCompare:firstFile.name];
	
	return result;
}

static NSComparisonResult sortFilesByTypeDesc(FileItem *firstFile, FileItem *secondFile, void *context) {
	NSComparisonResult result = NSOrderedSame;
	if ((firstFile.isDir && secondFile.isDir) ||
		(!firstFile.isDir && !secondFile.isDir)) {
		result = [firstFile.type caseInsensitiveCompare:secondFile.type];
		if (result == NSOrderedSame) {
			result = [firstFile.name caseInsensitiveCompare:secondFile.name];
		}
	} else if (firstFile.isDir) {
		result = NSOrderedAscending;
	} else if (secondFile.isDir) {
		result = NSOrderedDescending;
	}
	
	return result;
}

static NSComparisonResult sortFilesByTypeAsc(FileItem *firstFile, FileItem *secondFile, void *context) {
	NSComparisonResult result = NSOrderedSame;
	if ((firstFile.isDir && secondFile.isDir) ||
		(!firstFile.isDir && !secondFile.isDir)) {
		result = [secondFile.type caseInsensitiveCompare:firstFile.type];
		if (result == NSOrderedSame) {
			result = [firstFile.name caseInsensitiveCompare:secondFile.name];
		}
	} else if (firstFile.isDir) {
		result = NSOrderedDescending;
	} else if (secondFile.isDir) {
		result = NSOrderedAscending;
	}
	
	return result;
}

static NSComparisonResult sortFilesByTypeFoldersFirstDesc(FileItem *firstFile, FileItem *secondFile, void *context) {
	return sortFilesByTypeDesc(firstFile, secondFile, context);
}

static NSComparisonResult sortFilesByTypeFoldersFirstAsc(FileItem *firstFile, FileItem *secondFile, void *context) {
	NSComparisonResult result = NSOrderedSame;
	if ((firstFile.isDir && secondFile.isDir) ||
		(!firstFile.isDir && !secondFile.isDir)) {
		result = [secondFile.type caseInsensitiveCompare:firstFile.type];
		if (result == NSOrderedSame) {
			result = [firstFile.name caseInsensitiveCompare:secondFile.name];
		}
	} else if (firstFile.isDir) {
		result = NSOrderedAscending;
	} else if (secondFile.isDir) {
		result = NSOrderedDescending;
	}
	
	return result;
}

#pragma mark - Ordering functions

- (void)sortFileItemArrayWithOrder:(FileItemSortType)sortType
{
    switch (sortType) {
        case SORT_BY_NAME_DESC:
        {
            [self sortUsingFunction:sortFilesByNameDesc context: NULL];
            break;
        }
        case SORT_BY_NAME_DESC_FOLDER_FIRST:
        {
            [self sortUsingFunction:sortFilesByNameFoldersFirstDesc context: NULL];
            break;
        }
        case SORT_BY_NAME_ASC:
        {
            [self sortUsingFunction:sortFilesByNameAsc context: NULL];
            break;
        }
        case SORT_BY_NAME_ASC_FOLDER_FIRST:
        {
            [self sortUsingFunction:sortFilesByNameFoldersFirstAsc context: NULL];
            break;
        }
        case SORT_BY_DATE_DESC:
        {
            [self sortUsingFunction:sortFilesByDateDesc context: NULL];
            break;
        }
        case SORT_BY_DATE_DESC_FOLDER_FIRST:
        {
            [self sortUsingFunction:sortFilesByDateFoldersFirstDesc context: NULL];
            break;
        }
        case SORT_BY_DATE_ASC:
        {
            [self sortUsingFunction:sortFilesByDateAsc context: NULL];
            break;
        }
        case SORT_BY_DATE_ASC_FOLDER_FIRST:
        {
            [self sortUsingFunction:sortFilesByDateFoldersFirstAsc context: NULL];
            break;
        }
        case SORT_BY_TYPE_DESC:
        {
            [self sortUsingFunction:sortFilesByTypeDesc context: NULL];
            break;
        }
        case SORT_BY_TYPE_DESC_FOLDER_FIRST:
        {
            [self sortUsingFunction:sortFilesByTypeFoldersFirstAsc context: NULL];
            break;
        }
        case SORT_BY_TYPE_ASC:
        {
            [self sortUsingFunction:sortFilesByTypeAsc context: NULL];
            break;
        }
        case SORT_BY_TYPE_ASC_FOLDER_FIRST:
        {
            [self sortUsingFunction:sortFilesByTypeFoldersFirstDesc context: NULL];
            break;
        }
        case SORT_BY_SIZE_DESC:
        {
            [self sortUsingFunction:sortFilesBySizeDesc context: NULL];
            break;
        }
        case SORT_BY_SIZE_DESC_FOLDER_FIRST:
        {
            [self sortUsingFunction:sortFilesBySizeFoldersFirstDesc context: NULL];
            break;
        }
        case SORT_BY_SIZE_ASC:
        {
            [self sortUsingFunction:sortFilesBySizeAsc context: NULL];
            break;
        }
        case SORT_BY_SIZE_ASC_FOLDER_FIRST:
        {
            [self sortUsingFunction:sortFilesBySizeFoldersFirstAsc context: NULL];
            break;
        }
        default:
        {
            break;
        }
    }
}

@end
