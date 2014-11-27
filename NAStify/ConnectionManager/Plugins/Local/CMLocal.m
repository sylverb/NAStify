//
//  CMLocal.mm
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//
//  TODO :
//  - add 7z compression
//  - add bz2, gz and tar unarchiving

#import "CMLocal.h"
#import "NSNumberAdditions.h"
#import "UIDeviceHardware.h"

/* To get local IP */
#include <ifaddrs.h>
#include <arpa/inet.h>

#ifndef APP_EXTENSION
/* To check if Google Cast is connected */
#import "GoogleCastController.h"

/* Zip support */
#import "ZipFile.h"
#import "ZipException.h"
#import "FileInZipInfo.h"
#import "ZipWriteStream.h"
#import "ZipReadStream.h"

/* Rar support */
#import "RarFile.h"
#import "RarException.h"
#import "FileInRarInfo.h"

/* 7z support */
#import "P7zFile.h"
#import "P7zException.h"
#import "FileInp7zInfo.h"
#endif

#define BUFFER_SIZE 512*1024

@interface CMLocal (Private)
- (BOOL)isCompressed:(NSString *)type;
- (NSMutableArray *)itemsInFolder:(NSString *)path addFolderElement:(BOOL)addFolder;
- (NSMutableArray *)expandFileList:(NSArray *)fileList addFolderElement:(BOOL)addFolder;
#ifndef APP_EXTENSION
- (NSString *)getIPAddress;
#endif
@end

@implementation CMLocal

- (id)init
{
    self = [super init];
    if (self)
    {
        self.fileManager = [NSFileManager defaultManager];
    }
    return self;
}

- (NSArray *)serverInfo
{
    NSArray *serverInfo = [NSArray arrayWithObjects:
                           [NSString stringWithFormat:NSLocalizedString(@"%@",nil), [[UIDevice currentDevice] name]],
                           [NSString stringWithFormat:NSLocalizedString(@"Device : %@",nil), [[UIDevice currentDevice] platformString]],
                           [NSString stringWithFormat:NSLocalizedString(@"Model : %@ (%@)",nil),
                            [[UIDevice currentDevice] platform],
                            [[UIDevice currentDevice] hwmodel]],
                           [NSString stringWithFormat:NSLocalizedString(@"Total Space : %lld GB",nil),[[[UIDevice currentDevice] totalDiskSpace] longLongValue]/(1024*1024*1024)],
                           [NSString stringWithFormat:NSLocalizedString(@"OS : %@ %@",nil),[[UIDevice currentDevice] systemName],[[UIDevice currentDevice] systemVersion]],
                           nil];
    return serverInfo;
}

- (void)listForPath:(FileItem *)folder
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        NSArray *filesArray = [self.fileManager contentsOfDirectoryAtPath:folder.fullPath error:&error];
        NSMutableArray *filesOutputArray = [NSMutableArray arrayWithCapacity:[filesArray count]];
        
        for (NSString *fileNFD in filesArray)
        {
            // We don't want to show "/Inbox" folder
            if (!([folder.path isEqual:@"/"] && [fileNFD isEqual:@"Inbox"]))
            {
                // filenames are UTF-8 NFD encoded (due to HFS filesystem),
                // we convert it to UTF-8 NFC to simplify encoding management
                NSString *file = [fileNFD precomposedStringWithCanonicalMapping];
                NSString *filePath = [folder.fullPath stringByAppendingPathComponent:file];
                NSDictionary *fileAttrib = [self.fileManager attributesOfItemAtPath:filePath error:&error];
                
                /* Is it a directory */
                BOOL isDir = [[fileAttrib objectForKey:@"NSFileType"] isEqualToString:NSFileTypeDirectory];
                
                /* File type */
                NSString *fileType = nil;
                if ((!isDir) && ([[file componentsSeparatedByString:@"."] count] > 1))
                {
                    fileType = [[file componentsSeparatedByString:@"."] lastObject];
                }
                else
                {
                    fileType = @"";
                }
                
                /* Date */
                NSDate *mdate = [fileAttrib objectForKey:NSFileModificationDate];
                NSNumber *fileDateNumber = [NSNumber numberWithDouble:[mdate timeIntervalSince1970]];
                
                /* permission */
                NSNumber *permission = [fileAttrib objectForKey:@"NSFilePosixPermissions"];
                BOOL writeAccess = [permission userHasWriteAccessFromPosixPermissions];
                
                BOOL isCompressed = NO;
                if (fileType)
                {
                    isCompressed = [self isCompressed:fileType];
                }
                
                NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithBool:isDir],@"isdir",
                                          file,@"filename",
                                          filePath,@"path",
                                          [fileAttrib objectForKey:NSFileSize],@"filesizenumber",
                                          [NSNumber numberWithBool:isCompressed],@"iscompressed",
                                          [NSNumber numberWithBool:writeAccess],@"writeaccess",
                                          fileDateNumber,@"date",
                                          fileType,@"type",
                                          nil];
                
                [filesOutputArray addObject:dictItem];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMFilesList:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES],@"success",
                                        folder.path,@"path",
                                        filesOutputArray,@"filesList",
                                        nil]];
        });
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

#ifndef APP_EXTENSION
- (void)spaceInfoAtPath:(FileItem *)folder
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMSpaceInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:YES],@"success",
                                        [[UIDevice currentDevice] totalDiskSpace],@"totalspace",
                                        [[UIDevice currentDevice] freeDiskSpace],@"freespace",
                                        nil]];
        });
        
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}
#endif

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        
        BOOL folderCreated = [self.fileManager createDirectoryAtPath:[folder.fullPath stringByAppendingPathComponent:folderName]
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:&error];
        
        if (folderCreated)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCreateFolder:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error localizedDescription],@"error",
                                               nil]];
            });
        }
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

#ifndef APP_EXTENSION
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        
        NSString *fileSource = [folder.fullPath stringByAppendingPathComponent:oldFile.name];
        NSString *fileDest = [folder.fullPath stringByAppendingPathComponent:newName];
        
        BOOL fileRenamed = [self.fileManager moveItemAtPath:fileSource toPath:fileDest error:&error];
        
        if (fileRenamed)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:YES],@"success",
                                         nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMRename:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithBool:NO],@"success",
                                         [error localizedDescription],@"error",
                                         nil]];
            });
        }
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}
#endif

#ifndef APP_EXTENSION
- (void)deleteFiles:(NSArray *)files
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        
        BOOL fileDeleted = YES;
        for (FileItem *file in files)
        {
            fileDeleted = [self.fileManager removeItemAtPath:file.fullPath error:&error];
            if (!fileDeleted)
            {
                //FIXME: There is a problem, stop here and report it
                break;
            }
        }
        
        if (fileDeleted)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:YES],@"success",
                                                 nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDeleteFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 [NSNumber numberWithBool:NO],@"success",
                                                 [error localizedDescription],@"error",
                                                 nil]];
            });
        }
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}
#endif

#ifndef APP_EXTENSION
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        
        BOOL fileMoved = YES;
        for (FileItem *file in files)
        {
            NSString *fileDest = [destFolder.fullPath stringByAppendingPathComponent:file.name];
            // If we want to overwrite but destination file exists, delete existing file before moving
            if ((overwrite) && ([self.fileManager fileExistsAtPath:fileDest]))
            {
                [self.fileManager removeItemAtPath:fileDest error:nil];
            }
            
            fileMoved = [self.fileManager moveItemAtPath:file.fullPath
                                                  toPath:fileDest
                                                   error:&error];
            if (!fileMoved)
            {
                // There was a problem with one file, stop here and report error
                break;
            }
        }
        
        if (fileMoved)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMMoveFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error localizedDescription],@"error",
                                               nil]];
            });
        }
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}
#endif

#ifndef APP_EXTENSION
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        
        BOOL fileCopied = YES;
        for (FileItem *file in files)
        {
            NSString *fileDest = [destFolder.fullPath stringByAppendingPathComponent:file.name];
            
            // If we want to overwrite but destination file exists, delete existing file before copying
            if ((overwrite) && ([self.fileManager fileExistsAtPath:fileDest]))
            {
                [self.fileManager removeItemAtPath:fileDest error:nil];
            }
            
            fileCopied = [self.fileManager copyItemAtPath:file.fullPath
                                                   toPath:fileDest
                                                    error:&error];
            if (!fileCopied)
            {
                // There was a problem with one file, stop here and report error
                break;
            }
        }
        
        if (fileCopied)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCopyFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error localizedDescription],@"error",
                                               nil]];
            });
        }
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    });
}
#endif

- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        // Go to documents folder
        NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
        NSString *path = [containerURL.path stringByAppendingString:@"/Documents/"];

        NSError *error = nil;
        NSMutableArray *filesArray = [self itemsInFolder:folder.path addFolderElement:YES];
        NSMutableArray *filesOutputArray = [NSMutableArray array];
        
        for (NSString *file in filesArray)
        {
            NSString *filename = [file lastPathComponent];
            NSRange range = [filename rangeOfString:searchString
                                            options:(NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch)];
            if (range.location != NSNotFound)
            {
                NSString *filePath = [path stringByAppendingPathComponent:file];
                NSDictionary *fileAttrib = [self.fileManager attributesOfItemAtPath:filePath error:&error];
                
                /* Is it a directory */
                BOOL isDir = [[fileAttrib objectForKey:@"NSFileType"] isEqualToString:NSFileTypeDirectory];
                
                /* File type */
                NSString *fileType = nil;
                if ((!isDir) && ([[file componentsSeparatedByString:@"."] count] > 1))
                {
                    fileType = [file pathExtension];
                }
                else
                {
                    fileType = @"";
                }
                
                /* Date */
                NSDate *mdate = [fileAttrib objectForKey:NSFileModificationDate];
                NSNumber *fileDateNumber = [NSNumber numberWithDouble:[mdate timeIntervalSince1970]];
                
                /* permission */
                NSNumber *permission = [fileAttrib objectForKey:@"NSFilePosixPermissions"];
                BOOL writeAccess = [permission userHasWriteAccessFromPosixPermissions];
                
                BOOL isCompressed = [self isCompressed:fileType];
                
                NSDictionary *dictItem = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithBool:isDir],@"isdir",
                                          filename,@"filename",
                                          file,@"path",
                                          filePath,@"fullpath",
                                          [fileAttrib objectForKey:NSFileSize],@"filesizenumber",
                                          [NSNumber numberWithBool:isCompressed],@"iscompressed",
                                          [NSNumber numberWithBool:writeAccess],@"writeaccess",
                                          fileDateNumber,@"date",
                                          fileType,@"type",
                                          nil];
                
                [filesOutputArray addObject:dictItem];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate CMSearchFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSNumber numberWithBool:YES],@"success",
                                             folder.path,@"path",
                                             filesOutputArray,@"filesList",
                                             nil]];
        });
        
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

#ifndef APP_EXTENSION
- (void)compressFiles:(NSArray *)files
            toArchive:(NSString *)archive
          archiveType:(ARCHIVE_TYPE)archiveType
     compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel
             password:(NSString *)password
            overwrite:(BOOL)overwrite
{
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        @try {
            switch (archiveType)
            {
                case ARCHIVE_TYPE_ZIP:
                {
                    NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
                    NSString *path = [containerURL.path stringByAppendingString:@"/Documents/"];
                    
                    NSString *localArchive = [path stringByAppendingString:archive];
                    
                    // Parse content of folders if needed to create the list of files to add
                    NSMutableArray *expandedFileList = [self expandFileList:files addFolderElement:NO];
                    
                    // Get the total size of files to be added in archive
                    long long totalSize = 0;
                    NSError *error;
                    for (NSString *file in expandedFileList)
                    {
                        NSDictionary *fileAttrib = [self.fileManager attributesOfItemAtPath:[path stringByAppendingString:file]
                                                                                      error:&error];
                        totalSize+= [[fileAttrib objectForKey:NSFileSize] longLongValue];
                    }
                    
                    // Create zip file
                    long long compressedSize = 0;
                    ZipFile *zipFile= [[ZipFile alloc] initWithFileName:localArchive mode:ZipFileModeCreate];
                    
                    ZipCompressionLevel level = ZipCompressionLevelDefault;
                    switch (compressionLevel)
                    {
                        case ARCHIVE_COMPRESSION_LEVEL_NONE:
                        {
                            level = ZipCompressionLevelNone;
                            break;
                        }
                        case ARCHIVE_COMPRESSION_LEVEL_FASTEST:
                        {
                            level = ZipCompressionLevelFastest;
                            break;
                        }
                        case ARCHIVE_COMPRESSION_LEVEL_NORMAL:
                        {
                            level = ZipCompressionLevelDefault;
                            break;
                        }
                        case ARCHIVE_COMPRESSION_LEVEL_BEST:
                        {
                            level = ZipCompressionLevelBest;
                            break;
                        }
                    }
                    
                    for (NSString *fileToAdd in expandedFileList)
                    {
                        NSString *localFileToAdd = [path stringByAppendingString:fileToAdd];
                        
                        // Write file into zip
                        NSString *filenameInZip = [fileToAdd substringFromIndex:[((FileItem *)[files objectAtIndex:0]).shortPath length]];
                        ZipWriteStream *writeStream = nil;
                        if ((password != nil) && ([password length] !=0))
                        {
                            unsigned long fileCRC = crc32(0L, NULL, 0L);
                            
                            NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:localFileToAdd];
                            
                            NSData *databuffer = nil;
                            while ((databuffer == nil) || ([databuffer length] != 0))
                            {
                                @autoreleasepool {
                                    databuffer = [file readDataOfLength:BUFFER_SIZE]; // Read buffer size
                                    if ([databuffer length] != 0)
                                    {
                                        fileCRC = crc32( fileCRC, (const Bytef*)[databuffer bytes], (uInt)[databuffer length] );
                                    }
                                }
                            }
                            
                            [file closeFile];
                            writeStream = [zipFile writeFileInZipWithName:filenameInZip
                                                                 fileDate:[NSDate date]
                                                         compressionLevel:level
                                                                 password:password
                                                                    crc32:fileCRC];
                        }
                        else
                        {
                            writeStream = [zipFile writeFileInZipWithName:filenameInZip
                                                                 fileDate:[NSDate date]
                                                         compressionLevel:level];
                        }
                        
                        
                        NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:localFileToAdd];
                        
                        NSData *databuffer = nil;
                        while ((databuffer == nil) || ([databuffer length] != 0))
                        {
                            @autoreleasepool {
                                databuffer = [file readDataOfLength:BUFFER_SIZE]; // Read buffer size
                                compressedSize += [databuffer length];
                                if ([databuffer length] != 0)
                                {
                                    [writeStream writeData:databuffer];
                                    
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [self.delegate CMCompressProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                           [NSNumber numberWithLongLong:compressedSize],@"compressedBytes",
                                                                           [NSNumber numberWithLongLong:totalSize],@"totalBytes",
                                                                           [NSNumber numberWithFloat:(float)((float)compressedSize/(float)totalSize)],@"progress",
                                                                           fileToAdd,@"currentFile",
                                                                           nil]];
                                    });
                                }
                            }
                        }
                        [file closeFile];
                        
                        [writeStream finishedWriting];
                    }
                    [zipFile close];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:YES],@"success",
                                                           nil]];
                    });
                    break;
                }
                default:
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                           [NSNumber numberWithBool:NO],@"success",
                                                           @"Unsupported archive type",@"error",
                                                           nil]];
                    });
                    break;
                }
            }
            [[UIApplication sharedApplication] endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        }
        @catch (ZipException *ze) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMCompressFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [ze reason],@"error",
                                                   nil]];
            });
        }
    });
}
#endif

#ifndef APP_EXTENSION
- (void)extractFiles:(NSArray *)files
            toFolder:(FileItem *)folder
        withPassword:(NSString *)password
           overwrite:(BOOL)overwrite
   extractWithFolder:(BOOL)extractFolders
{
    FileItem *fileItem = [files firstObject];

    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        @try {
            if ([fileItem.type isEqualToString:@"zip"])
            {
                NSError *error;
                ZipFile *unzipFile= [[ZipFile alloc] initWithFileName:fileItem.fullPath mode:ZipFileModeUnzip];
                
                NSArray *infos= [unzipFile listFileInZipInfos];
                
                long long int totalSize = 0;
                long long int extractedSize = 0;
                for (FileInZipInfo *info in infos)
                {
                    totalSize += info.length;
                }
                
                [unzipFile goToFirstFileInZip];
                
                NSMutableData *databuffer = [[NSMutableData alloc] init];
                for (FileInZipInfo *info in infos)
                {
                    if (info.name == nil)
                    {
                        continue;
                    }
                    // Initialize buffer size
                    [databuffer setLength:BUFFER_SIZE];

                    ZipReadStream *readStream = nil;
                    BOOL isFolder = NO;
                    if ([info.name hasSuffix:@"/"])
                    {
                        isFolder = YES;
                    }
                    
                    if ((password != nil) && ([password length] !=0))
                    {
                        readStream = [unzipFile readCurrentFileInZipWithPassword:password];
                    }
                    else
                    {
                        readStream = [unzipFile readCurrentFileInZip];
                    }
                    NSString *destFile = nil;
                    if (extractFolders)
                    {
                        // Don't use stringByAppendingPathComponent here as it removes slash at the end
                        // (which can happen if file is actually folder)
                        destFile = [NSString stringWithFormat:@"%@/%@",folder.fullPath,info.name];
                    }
                    else
                    {
                        if (isFolder)
                        {
                            // It's a folder, do not create it !
                            destFile = nil;
                        }
                        else
                        {
                            destFile = [folder.fullPath stringByAppendingPathComponent:[info.name lastPathComponent]];
                        }
                    }
                    
                    NSFileHandle *file = nil;
                    if ((isFolder) && (!extractFolders))
                    {
                        // Nothing to do
                    }
                    else if ((isFolder) && (extractFolders))
                    {
                        [self.fileManager createDirectoryAtPath:destFile
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:&error];
                    }
                    else
                    {
                        file = [NSFileHandle fileHandleForWritingAtPath:destFile];
                        if ((file) && (!overwrite))
                        {
                            // do not overwrite existing file
                            file = nil;
                        }
                        else if (file)
                        {
                            // We are overwriting file, clean previous file
                            [file truncateFileAtOffset:0];
                        }
                        else
                        {
                            // create folders if needed
                            NSMutableArray *folders = [NSMutableArray arrayWithArray:[info.name componentsSeparatedByString:@"/"]];
                            if ([folders count] > 1)
                            {
                                [folders removeLastObject];
                                [self.fileManager createDirectoryAtPath:[folder.fullPath stringByAppendingPathComponent:[folders componentsJoinedByString:@"/"]]
                                            withIntermediateDirectories:YES
                                                             attributes:nil
                                                                  error:&error];
                            }
                            [self.fileManager createFileAtPath:destFile
                                                      contents:nil
                                                    attributes:nil];
                            file = [NSFileHandle fileHandleForWritingAtPath:destFile];
                        }
                    }
                    
                    if ((file) && (!error))
                    {
                        while (1)
                        {
                            @autoreleasepool {
                                NSUInteger readSize = [readStream readDataWithBuffer:databuffer];
                                
                                extractedSize += readSize;
                                if (readSize != 0)
                                {
                                    // Write correct amount of data
                                    [databuffer setLength:readSize];
                                    [file writeData:databuffer];
                                    
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [self.delegate CMExtractProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                          [NSNumber numberWithLongLong:extractedSize],@"extractedBytes",
                                                                          [NSNumber numberWithLongLong:totalSize],@"totalBytes",
                                                                          [NSNumber numberWithFloat:(float)((float)extractedSize/(float)totalSize)],@"progress",
                                                                          info.name,@"currentFile",
                                                                          nil]];
                                    });
                                }
                                else
                                {
                                    break;
                                }
                            }
                        }
                        
                        [file closeFile];
                    }
                    else
                    {
                        // File skipped
                        extractedSize += info.size;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.delegate CMExtractProgress:[NSDictionary dictionaryWithObjectsAndKeys:
                                                              [NSNumber numberWithFloat:(float)((float)extractedSize/(float)totalSize)],@"progress",
                                                              info.name,@"currentFile",
                                                              nil]];
                        });
                    }
                    [readStream finishedReading];
                    [unzipFile goToNextFileInZip];
                }
                [unzipFile close];
                
                if (error == nil)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          [NSNumber numberWithBool:YES],@"success",
                                                          nil]];
                    });
                }
                else
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          [NSNumber numberWithBool:NO],@"success",
                                                          [error localizedDescription],@"error",
                                                          nil]];
                    });
                }
            }
            else if ([fileItem.type isEqualToString:@"rar"])
            {
                RarFile *rarFile = [[RarFile alloc] initWithFileName:fileItem.fullPath];
                
                [rarFile goToFirstFileInRar];
                
                [rarFile extractFilesTo:folder.fullPath password:password];
                
                [rarFile close];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:YES],@"success",
                                                      nil]];
                });
            }
            else if ([fileItem.type isEqualToString:@"7z"])
            {
                P7zFile *p7zFile = [[P7zFile alloc] initWithFileName:fileItem.fullPath];
                
                [p7zFile extractFilesTo:folder.fullPath
                               password:password
                         extractFolders:extractFolders];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:YES],@"success",
                                                      nil]];
                });
            }
            [[UIApplication sharedApplication] endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        }
        @catch (ZipException *ze) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:NO],@"success",
                                                  [ze reason],@"error",
                                                  nil]];
            });
        }
        @catch (RarException *re) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:NO],@"success",
                                                  [re reason],@"error",
                                                  nil]];
            });
        }
        @catch (P7zException *p7e) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMExtractFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithBool:NO],@"success",
                                                  [p7e reason],@"error",
                                                  nil]];
            });
        }
    });
}
#endif

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        
        // Delete existing file before copying
        if ([self.fileManager fileExistsAtPath:localName])
        {
            [self.fileManager removeItemAtPath:localName error:nil];
        }

        if ([self.fileManager copyItemAtPath:file.fullPath
                                      toPath:localName
                                       error:&error])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:YES],@"success",
                                                   nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMDownloadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSNumber numberWithBool:NO],@"success",
                                                   [error localizedDescription],@"error",
                                                   nil]];
            });
        }
    });
}

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
#ifndef APP_EXTENSION
    __block UIBackgroundTaskIdentifier bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
#endif
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSError *error = nil;
        
        NSString *fileDest = [destFolder.fullPath stringByAppendingPathComponent:file.name];
        
        // If we want to overwrite but destination file exists, delete existing file before moving
        if ((overwrite) && ([self.fileManager fileExistsAtPath:fileDest]))
        {
            [self.fileManager removeItemAtPath:fileDest error:nil];
        }
        
        if ([self.fileManager copyItemAtPath:file.fullPath
                                      toPath:fileDest
                                       error:&error])
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES],@"success",
                                               nil]];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate CMUploadFinished:[NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:NO],@"success",
                                               [error localizedDescription],@"error",
                                               nil]];
            });
        }
#ifndef APP_EXTENSION
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
#endif
    });
}

#ifndef APP_EXTENSION
- (NetworkConnection *)urlForVideo:(FileItem *)file
{
    NSError *error;
    NetworkConnection *networkConnection;
    
    // If we want to serve video to Google Cast, we have to create a
    // HTTP server and to send video's URL to the Google Cast.
    if ([[GoogleCastController sharedGCController] isConnected])
    {
        if (self.httpServer == nil)
        {
            self.httpServer = [[HTTPServer alloc] init];
//          [self.httpServer setType:@"_http._tcp."];
            // Serve documents folder
            NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
            NSString *path = [containerURL.path stringByAppendingString:@"/Documents/"];

            [self.httpServer setDocumentRoot:path];
            if([self.httpServer start:&error])
            {
                NSLog(@"Started HTTP Server %@:%hu", [self getIPAddress], [self.httpServer listeningPort]);
            }
            else
            {
                NSLog(@"Error starting HTTP Server: %@", error);
            }
        }
        
        networkConnection = [[NetworkConnection alloc] init];
        networkConnection.url = [NSURL URLWithString:
                                 [NSString stringWithFormat:@"http://%@:%hu%@",
                                  [self getIPAddress],
                                  [self.httpServer listeningPort],
                                  file.path]];
        networkConnection.urlType = URLTYPE_HTTP;
    }
    else
    {
        networkConnection = [self urlForFile:file];
    }
    
  	return networkConnection;
}
#endif

#ifndef APP_EXTENSION
- (NetworkConnection *)urlForFile:(FileItem *)file
{
    NetworkConnection *networkConnection = [[NetworkConnection alloc] init];
    networkConnection.url = [NSURL fileURLWithPath:file.fullPath];
    networkConnection.urlType = URLTYPE_LOCAL;
  	return networkConnection;
}
#endif

#pragma mark - supported features

- (NSInteger)supportedFeaturesAtPath:(NSString *)path
{
    NSInteger features = CMSupportedFeaturesMaskFileDelete     |
                         CMSupportedFeaturesMaskFolderDelete   |
                         CMSupportedFeaturesMaskFolderCreate   |
                         CMSupportedFeaturesMaskFileRename     |
                         CMSupportedFeaturesMaskFolderRename   |
                         CMSupportedFeaturesMaskFileMove       |
                         CMSupportedFeaturesMaskFolderMove     |
                         CMSupportedFeaturesMaskFileCopy       |
                         CMSupportedFeaturesMaskFolderCopy     |
                         CMSupportedFeaturesMaskCompress       |
                         CMSupportedFeaturesMaskExtract        |
                         CMSupportedFeaturesMaskSearch         |
                         CMSupportedFeaturesMaskFileDownload   |
#ifdef APP_EXTENSION
                         CMSupportedFeaturesMaskFileUpload     |
#endif
                         CMSupportedFeaturesMaskQTPlayer       |
                         CMSupportedFeaturesMaskVLCPlayer      |
                         CMSupportedFeaturesMaskVideoSeek      |
                         CMSupportedFeaturesMaskAirPlay        |
                         CMSupportedFeaturesMaskGoogleCast     |
                         CMSupportedFeaturesMaskOpenIn;
    
    return features;
}

#ifndef APP_EXTENSION
- (NSInteger)supportedArchiveType
{
    return CMSupportedArchivesMaskZip;
}
#endif

#pragma mark - Private methods

// Return true if this connection manager can extract this file type
- (BOOL)isCompressed:(NSString *)type
{
    BOOL supportedArchiveType = NO;
    if (([[type lowercaseString] isEqualToString:@"zip"]) ||
        ([[type lowercaseString] isEqualToString:@"rar"]) ||
        ([[type lowercaseString] isEqualToString:@"7z"]))
    {
        supportedArchiveType = YES;
    }
    return supportedArchiveType;
}

// Create a mutable array with expanded list of files at path (recursive method)
- (NSMutableArray *)itemsInFolder:(NSString *)path addFolderElement:(BOOL)addFolder
{
    NSURL *containerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:@"group.com.sylver.NAStify"];
    NSString *localPath = [containerURL.path stringByAppendingFormat:@"/Documents/%@",path];
    
    NSMutableArray *expandedArray = [NSMutableArray array];
    NSError *error = nil;
    
    NSArray *filesArray = [self.fileManager contentsOfDirectoryAtPath:localPath error:&error];
    for (NSString *file in filesArray)
    {
        NSDictionary *fileAttrib = [self.fileManager attributesOfItemAtPath:[localPath stringByAppendingPathComponent:file] error:&error];
        NSString *filePath = nil;
        filePath = [path stringByAppendingPathComponent:file];
        
        /* Is it a directory */
        if ([[fileAttrib objectForKey:@"NSFileType"] isEqualToString:NSFileTypeDirectory])
        {
            if (addFolder)
            {
                [expandedArray addObject:filePath];
            }
            [expandedArray addObjectsFromArray:[self itemsInFolder:[filePath stringByAppendingString:@"/"] addFolderElement:addFolder]];
        }
        else
        {
            [expandedArray addObject:filePath];
        }
    }
    return expandedArray;
}

- (NSMutableArray *)expandFileList:(NSArray *)fileList addFolderElement:(BOOL)addFolder
{
    NSMutableArray *expandedArray = [NSMutableArray array];
    for (FileItem *item in fileList)
    {
        if (item.isDir)
        {
            [expandedArray addObjectsFromArray:[self itemsInFolder:[item.path stringByAppendingString:@"/"] addFolderElement:addFolder]];
        }
        else
        {
            [expandedArray addObject:item.path];
        }
    }
    return expandedArray;
}

#ifndef APP_EXTENSION
- (NSString *)getIPAddress
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return address;
}
#endif

@end