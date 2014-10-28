//
//  RarFile.mm
//  Objective-rar v. 0.1
//
//  Created by Sylver Bruneau.
//
//  Based on Objective-Zip by Gianluca Bertani on 27/12/09.
//  Copyright 2009-10 Flying Dolphin Studio. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without 
//  modification, are permitted provided that the following conditions 
//  are met:
//
//  * Redistributions of source code must retain the above copyright notice, 
//    this list of conditions and the following disclaimer.
//  * Redistributions in binary form must reproduce the above copyright notice, 
//    this list of conditions and the following disclaimer in the documentation 
//    and/or other materials provided with the distribution.
//  * Neither the name of Gianluca Bertani nor the names of its contributors 
//    may be used to endorse or promote products derived from this software 
//    without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
//  POSSIBILITY OF SUCH DAMAGE.
//

#import "RarFile.h"
#import "RarException.h"
#import "FileInRarInfo.h"
#import "rar.hpp"

@implementation RarFile

- (id)initWithFileName:(NSString *)fileName
{
	if ((self = [super init]))
    {
        self.filename = fileName;
        fileCount = -1;
    }
	return self;
}

- (BOOL)_unrarOpenFileWithMode:(NSInteger)mode
{
	header = new RARHeaderDataEx;
	flags  = new RAROpenArchiveDataEx;
	
	const char *filenameData = (const char *) [self.filename UTF8String];
	flags->ArcName = new char[strlen(filenameData) + 1];
	strcpy(flags->ArcName, filenameData);
	flags->ArcNameW = NULL;
	flags->CmtBuf = NULL;
	flags->OpenMode = (unsigned int)mode;
	
	_rarFile = RAROpenArchiveEx(flags);
	if (flags->OpenResult != 0)
    {
		return NO;
	}
    if ((flags->Flags & MHD_COMMENT) != 0)
    {
        NSLog(@"MHD_COMMENT");
    }
    if ((flags->Flags & MHD_LOCK) != 0)
    {
        NSLog(@"MHD_LOCK");
    }
    if ((flags->Flags & MHD_SOLID) != 0)
    {
        NSLog(@"MHD_SOLID");
    }
    if ((flags->Flags & MHD_PACK_COMMENT) != 0)
    {
        NSLog(@"MHD_PACK_COMMENT");
    }
    if ((flags->Flags & MHD_NEWNUMBERING) != 0)
    {
        NSLog(@"MHD_NEWNUMBERING");
    }
    if ((flags->Flags & MHD_AV) != 0)
    {
        NSLog(@"MHD_AV");
    }
    if ((flags->Flags & MHD_PROTECT) != 0)
    {
        NSLog(@"MHD_PROTECT");
    }
    if ((flags->Flags & MHD_PASSWORD) != 0)
    {
        NSLog(@"MHD_PASSWORD");
    }
    if ((flags->Flags & MHD_FIRSTVOLUME) != 0)
    {
        NSLog(@"MHD_FIRSTVOLUME");
    }
    if ((flags->Flags & MHD_ENCRYPTVER) != 0)
    {
        NSLog(@"MHD_ENCRYPTVER");
    }

    
	header->CmtBuf = NULL;
    
	return YES;
}

- (BOOL)_unrarCloseFile
{
	if (_rarFile)
    {
		RARCloseArchive(_rarFile);
	}
    _rarFile = NULL;
	delete flags;
	return YES;
}

- (NSUInteger)numFilesInRar
{
    if (fileCount == -1)
    {
        int RHCode = 0, PFCode = 0;
        
        [self _unrarOpenFileWithMode:RAR_OM_LIST];
        
        fileCount = 0;
        while ((RHCode = RARReadHeaderEx(_rarFile, header)) == 0)
        {
            fileCount++;
            if ((PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL)) != 0) {
                [self _unrarCloseFile];
                return 0;
            }
        }
        
        if ((RHCode != 0) && (RHCode != ERAR_END_ARCHIVE))
        {
            [self errorExceptionForCode:RHCode];
            
            fileCount = -1;
        }
        [self _unrarCloseFile];
    }
    return fileCount;
}

- (void)errorExceptionForCode:(int)code
{
    NSString *reason = nil;

    switch (code)
    {
        case ERAR_NO_MEMORY:
        {
            reason= [NSString stringWithFormat:@"No memory"];
            break;
        }
        case ERAR_BAD_DATA:
        {
            reason= [NSString stringWithFormat:@"Bad data"];
            break;
        }
        case ERAR_BAD_ARCHIVE:
        {
            reason= [NSString stringWithFormat:@"Bad archive"];
            break;
        }
        case ERAR_UNKNOWN_FORMAT:
        {
            reason= [NSString stringWithFormat:@"Unknown format"];
            break;
        }
        case ERAR_EOPEN:
        {
            reason= [NSString stringWithFormat:@"ERAR_EOPEN"];
            break;
        }
        case ERAR_ECREATE:
        {
            reason= [NSString stringWithFormat:@"ERAR_ECREATE"];
            break;
        }
        case ERAR_ECLOSE:
        {
            reason= [NSString stringWithFormat:@"ERAR_ECLOSE"];
            break;
        }
        case ERAR_EREAD:
        {
            reason= [NSString stringWithFormat:@"ERAR_EREAD"];
            break;
        }
        case ERAR_EWRITE:
        {
            reason= [NSString stringWithFormat:@"ERAR_EWRITE"];
            break;
        }
        case ERAR_SMALL_BUF:
        {
            reason= [NSString stringWithFormat:@"ERAR_SMALL_BUF"];
            break;
        }
        case ERAR_UNKNOWN:
        {
            reason= [NSString stringWithFormat:@"Unknown error"];
            break;
        }
        case ERAR_MISSING_PASSWORD:
        {
            reason= [NSString stringWithFormat:@"Missing Password"];
            break;
        }
        default:
            break;
    }
    @throw [[RarException alloc] initWithError:code reason:reason];
}

- (NSArray *) listFileInRarInfos
{
    NSInteger num = [self numFilesInRar];
	if (num < 1)
    {
		return nil;
	}
    
	NSMutableArray *files= [[NSMutableArray alloc] initWithCapacity:num];
    
	[self goToFirstFileInRar];
	for (int i= 0; i < num; i++)
    {
		FileInRarInfo *info= [self getCurrentFileInRarInfo];
		[files addObject:info];
        
		if ((i +1) < num)
        {
			[self goToNextFileInRar];
        }
	}    
	return files;
}

- (void) goToFirstFileInRar
{
    if (_rarFile)
    {
        [self _unrarCloseFile];
    }
    
	if ([self _unrarOpenFileWithMode:RAR_OM_EXTRACT] == NO)
    {
		NSString *reason= [NSString stringWithFormat:@"Error in going to first file in rar in '%@'", self.filename];
		@throw [[RarException alloc] initWithError:0 reason:reason];
    }
}

- (BOOL) goToNextFileInRar
{
    int PFCode = RARProcessFile(_rarFile, RAR_SKIP, NULL, NULL);
    if ((PFCode != 0) && (PFCode != ERAR_END_ARCHIVE))
    {
        [self errorExceptionForCode:PFCode];
        [self _unrarCloseFile];
        return NO;
    }
	return YES;
}

- (FileInRarInfo *) getCurrentFileInRarInfo
{
    FileInRarInfo *info = nil;
    if (RARReadHeaderEx(_rarFile, header) == 0)
    {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:header->FileTime];
        info= [[FileInRarInfo alloc] initWithName:[NSString stringWithUTF8String:header->FileName]
                                           length:header->UnpSize
                                          crypted:(header->Flags & MHD_PASSWORD)!=0
                                             size:header->PackSize
                                             date:date
                                            crc32:header->FileCRC];
    }
    return info;
}

static int callbackFunction(UINT msg, LPARAM userData, LPARAM paramOne, LPARAM paramTwo)
{
	switch(msg)
    {
		case UCM_CHANGEVOLUME:
        {
            printf("UCM_CHANGEVOLUME");
            switch (paramTwo) {
                case RAR_VOL_NOTIFY:
                {
                    // Nothing to do, next volume found
                    break;
                }
                case RAR_VOL_ASK:
                {
                    NSString *reason= @"Missing volume";
                    @throw [[RarException alloc] initWithError:UCM_NEEDPASSWORD reason:reason];
                    return -1;
                    break;
                }
            }
			break;
        }
		case UCM_PROCESSDATA:
        {
			break;
        }
		case UCM_NEEDPASSWORD:
        {
            NSString *reason= @"Wrong password";
            @throw [[RarException alloc] initWithError:UCM_NEEDPASSWORD reason:reason];
            return -1;
			break;
        }
	}
    return 0;
}

- (BOOL)extractFilesTo:(NSString *)destFolder password:(NSString *)password
{
    struct RARHeaderData headerData;
    
    //Determine the folder we should extract the archive to. This by default
	//is the <folderContainingTheArchive>/<archiveNameWithPathExtension>
	NSString * folderToExtractTo = [self.filename stringByDeletingLastPathComponent];
    
    if ((password != nil) && ([password length] != 0))
    {
        RARSetPassword(_rarFile, (char *)[password cStringUsingEncoding:NSISOLatin1StringEncoding]);
    }
    
	RARSetCallback(_rarFile, &callbackFunction, NULL);
    
    while (RARReadHeader(_rarFile, &headerData) != ERAR_END_ARCHIVE)
    {
		int processResult = 0;
		processResult = RARProcessFile(_rarFile, RAR_EXTRACT, (char *) [folderToExtractTo cStringUsingEncoding:NSISOLatin1StringEncoding], NULL);
		
		if (processResult != 0)
        {
            if (processResult != ERAR_UNKNOWN) // Exeptions of kind "unknown" are raised in the callback function
            {
                [self errorExceptionForCode:processResult];
            }
			break;
		}
	}
    return YES;
}

- (void) close
{
    [self _unrarCloseFile];
}


@end
