//
//  7zFile.m
//  Objective-7z v. 0.1
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

#import "P7zFile.h"
#import "P7zException.h"
#import "FileInp7zInfo.h"

#include <stdio.h>
#include <string.h>

#include "7z.h"
#include "7zAlloc.h"
#include "7zCrc.h"
#include "7zFile.h"
#include "7zVersion.h"
#include <sys/stat.h>
#include <errno.h>

static ISzAlloc g_Alloc = { SzAlloc, SzFree };

static void GetAttribString(UInt32 wa, Bool isDir, char *s);
static void UInt64ToStr(UInt64 value, char *s);
static char *UIntToStr(char *s, unsigned value, int numDigits);
static Byte kUtf8Limits[5] = { 0xC0, 0xE0, 0xF0, 0xF8, 0xFC };

static Bool Utf16_To_Utf8(Byte *dest, size_t *destLen, const UInt16 *src, size_t srcLen);
static int Buf_EnsureSize(CBuf *dest, size_t size);
static SRes Utf16_To_Utf8Buf(CBuf *dest, const UInt16 *src, size_t srcLen);
static SRes Utf16_To_Char(CBuf *buf, const UInt16 *s, int fileMode);
static void ConvertFileTimeToString(const CNtfsFileTime *ft, char *s);
static WRes MyCreateDir(const UInt16 *name, const char *destFolder);
static WRes OutFile_OpenUtf16(CSzFile *p, const UInt16 *name, const char *folder);

@implementation P7zFile

- (id)initWithFileName:(NSString *)fileName
{
	if ((self = [super init]))
    {
        self.filename = fileName;
    }
	return self;
}

- (NSUInteger)numFilesInp7z
{
    CFileInStream archiveStream;
    CLookToRead lookStream;
    CSzArEx db;
    SRes res;
    ISzAlloc allocImp;
    ISzAlloc allocTempImp;
    NSUInteger fileCount = -1;
    
    allocImp.Alloc = SzAlloc;
    allocImp.Free = SzFree;
    
    allocTempImp.Alloc = SzAllocTemp;
    allocTempImp.Free = SzFreeTemp;
    
    if (InFile_Open(&archiveStream.file, [self.filename UTF8String]))
    {
        NSString *reason = @"Can't open input file";
        @throw [[P7zException alloc] initWithError:0 reason:reason];
        return NO;
    }
    
    FileInStream_CreateVTable(&archiveStream);
    LookToRead_CreateVTable(&lookStream, False);
    
    lookStream.realStream = &archiveStream.s;
    LookToRead_Init(&lookStream);
    
    CrcGenerateTable();

    SzArEx_Init(&db);
    res = SzArEx_Open(&db, &lookStream.s, &allocImp, &allocTempImp);
    if (res == SZ_OK)
    {
        fileCount = db.db.NumFiles;
    }
    SzArEx_Free(&db, &allocImp);
    
    File_Close(&archiveStream.file);
    return fileCount;
}

- (NSArray *) listFileInp7zInfos
{
	NSMutableArray *files = [[NSMutableArray alloc] init];

    CFileInStream archiveStream;
    CLookToRead lookStream;
    CSzArEx db;
    SRes res;
    ISzAlloc allocImp;
    ISzAlloc allocTempImp;
    UInt16 *temp = NULL;
    size_t tempSize = 0;

    allocImp.Alloc = SzAlloc;
    allocImp.Free = SzFree;
    
    allocTempImp.Alloc = SzAllocTemp;
    allocTempImp.Free = SzFreeTemp;
    
    if (InFile_Open(&archiveStream.file, [self.filename UTF8String]))
    {
        NSString *reason = @"Can't open input file";
        @throw [[P7zException alloc] initWithError:0 reason:reason];
        return NO;
    }
    
    FileInStream_CreateVTable(&archiveStream);
    LookToRead_CreateVTable(&lookStream, False);
    
    lookStream.realStream = &archiveStream.s;
    LookToRead_Init(&lookStream);
    
    CrcGenerateTable();
    
    SzArEx_Init(&db);
    res = SzArEx_Open(&db, &lookStream.s, &allocImp, &allocTempImp);
    if (res == SZ_OK)
    {
        if (res == SZ_OK)
        {
            UInt32 i;
            
            for (i = 0; i < db.db.NumFiles; i++)
            {
                const CSzFileItem *f = db.db.Files + i;
                if (!f->IsDir)
                {
                    size_t len;
                    
                    len = SzArEx_GetFileNameUtf16(&db, i, NULL);
                    
                    if (len > tempSize)
                    {
                        SzFree(NULL, temp);
                        tempSize = len;
                        temp = (UInt16 *)SzAlloc(NULL, tempSize * sizeof(temp[0]));
                        if (temp == 0)
                        {
                            break;
                        }
                    }
                    
                    SzArEx_GetFileNameUtf16(&db, i, temp);
                    
                    // date
                    NSDate *date = nil;
                    if (f->MTimeDefined)
                    {
                        UInt64 secondsSince1970 = (f->MTime.Low | ((UInt64)f->MTime.High << 32)) / 10000000;
                        date = [NSDate dateWithTimeIntervalSince1970:secondsSince1970];
                    }
                    
                    // name
                    CBuf buf;
                    Buf_Init(&buf);
                    Utf16_To_Char(&buf, temp, 1);
                    
                    FileInp7zInfo *fileInfo = [[FileInp7zInfo alloc] initWithName:[[NSString alloc] initWithBytes:buf.data
                                                                                                           length:buf.size
                                                                                                         encoding:NSUTF8StringEncoding]
                                                                             size:f->Size
                                                                             date:date];
                    [files addObject:fileInfo];
                }
            }
        }
    }
    SzArEx_Free(&db, &allocImp);
    
    File_Close(&archiveStream.file);

    return files;
}

- (BOOL)extractFilesTo:(NSString *)destFolder password:(NSString *)password extractFolders:(BOOL)extractFolders
{
    if ((password != nil) && ([password length] != 0))
    {
        NSString *reason = @"7z files with password are not supported";
        @throw [[P7zException alloc] initWithError:0 reason:reason];
        return NO;
    }

    CFileInStream archiveStream;
    CLookToRead lookStream;
    CSzArEx db;
    SRes res;
    ISzAlloc allocImp;
    ISzAlloc allocTempImp;
    UInt16 *temp = NULL;
    size_t tempSize = 0;
    
    allocImp.Alloc = SzAlloc;
    allocImp.Free = SzFree;
    
    allocTempImp.Alloc = SzAllocTemp;
    allocTempImp.Free = SzFreeTemp;
    
    if (InFile_Open(&archiveStream.file, [self.filename UTF8String]))
    {
        NSString *reason = @"Can't open input file";
        @throw [[P7zException alloc] initWithError:0 reason:reason];
        return NO;
    }
    
    FileInStream_CreateVTable(&archiveStream);
    LookToRead_CreateVTable(&lookStream, False);
    
    lookStream.realStream = &archiveStream.s;
    LookToRead_Init(&lookStream);
    
    CrcGenerateTable();
    
    SzArEx_Init(&db);
    res = SzArEx_Open(&db, &lookStream.s, &allocImp, &allocTempImp);
    if (res == SZ_OK)
    {
        UInt32 i;
        
        /*
         if you need cache, use these 3 variables.
         if you use external function, you can make these variable as static.
         */
        UInt32 blockIndex = 0xFFFFFFFF; /* it can have any value before first call (if outBuffer = 0) */
        Byte *outBuffer = 0; /* it must be 0 before first call for each new archive. */
        size_t outBufferSize = 0;  /* it can have any value before first call (if outBuffer = 0) */
        
        for (i = 0; i < db.db.NumFiles; i++)
        {
            size_t offset = 0;
            size_t outSizeProcessed = 0;
            const CSzFileItem *f = db.db.Files + i;
            size_t len;
            if (f->IsDir && !extractFolders)
                continue;
            len = SzArEx_GetFileNameUtf16(&db, i, NULL);
            
            if (len > tempSize)
            {
                SzFree(NULL, temp);
                tempSize = len;
                temp = (UInt16 *)SzAlloc(NULL, tempSize * sizeof(temp[0]));
                if (temp == 0)
                {
                    res = SZ_ERROR_MEM;
                    break;
                }
            }
            
            SzArEx_GetFileNameUtf16(&db, i, temp);
            
            if (res != SZ_OK)
            {
                break;
            }
            if (!f->IsDir)
            {
                res = SzArEx_Extract(&db, &lookStream.s, i,
                                     &blockIndex, &outBuffer, &outBufferSize,
                                     &offset, &outSizeProcessed,
                                     &allocImp, &allocTempImp);
                if (res != SZ_OK)
                    break;
            }
            CSzFile outFile;
            size_t processedSize;
            size_t j;
            UInt16 *name = (UInt16 *)temp;
            const UInt16 *destPath = (const UInt16 *)name;
            
            for (j = 0; name[j] != 0; j++)
            {
                if (name[j] == '/')
                {
                    if (extractFolders)
                    {
                        name[j] = 0;
                        MyCreateDir(name,[destFolder UTF8String]);
                        name[j] = CHAR_PATH_SEPARATOR;
                    }
                    else
                    {
                        destPath = name + j + 1;
                    }
                }
            }
            
            if (f->IsDir)
            {
                MyCreateDir(destPath,[destFolder UTF8String]);
                continue;
            }
            else if (OutFile_OpenUtf16(&outFile, destPath, [destFolder UTF8String]))
            {
                CBuf buf;
                Buf_Init(&buf);
                RINOK(Utf16_To_Char(&buf, destPath, 1));
                NSString *reason= [NSString stringWithFormat:@"Can't open output file '%s'", (const char *)buf.data];
                @throw [[P7zException alloc] initWithError:0 reason:reason];
                break;
            }
            processedSize = outSizeProcessed;
            if (File_Write(&outFile, outBuffer + offset, &processedSize) != 0 || processedSize != outSizeProcessed)
            {
                CBuf buf;
                Buf_Init(&buf);
                RINOK(Utf16_To_Char(&buf, destPath, 1));
                NSString *reason= [NSString stringWithFormat:@"Can't write output file '%s'", (const char *)buf.data];
                @throw [[P7zException alloc] initWithError:0 reason:reason];
                break;
            }
            if (File_Close(&outFile))
            {
                CBuf buf;
                Buf_Init(&buf);
                RINOK(Utf16_To_Char(&buf, destPath, 1));
                NSString *reason= [NSString stringWithFormat:@"Can't close output file '%s'", (const char *)buf.data];
                @throw [[P7zException alloc] initWithError:0 reason:reason];
                break;
            }
        }
        IAlloc_Free(&allocImp, outBuffer);
    }
    SzArEx_Free(&db, &allocImp);
    SzFree(NULL, temp);
    
    File_Close(&archiveStream.file);
    if (res == SZ_OK)
    {
        // Everything is Ok
    }
    else if (res == SZ_ERROR_UNSUPPORTED)
    {
        NSString *reason = @"decoder doesn't support this archive";
        @throw [[P7zException alloc] initWithError:0 reason:reason];
    }
    else if (res == SZ_ERROR_MEM)
    {
        NSString *reason = @"can not allocate memory";
        @throw [[P7zException alloc] initWithError:0 reason:reason];
    }
    else if (res == SZ_ERROR_CRC)
    {
        NSString *reason = @"CRC error";
        @throw [[P7zException alloc] initWithError:0 reason:reason];
    }
    else
    {
        NSString *reason = [NSString stringWithFormat:@"Error %d", res];
        @throw [[P7zException alloc] initWithError:0 reason:reason];
    }
    return YES;
}

@end

#pragma mark - c functions

static void GetAttribString(UInt32 wa, Bool isDir, char *s)
{
    s[0] = '\0';
}

static void UInt64ToStr(UInt64 value, char *s)
{
    char temp[32];
    int pos = 0;
    do
    {
        temp[pos++] = (char)('0' + (unsigned)(value % 10));
        value /= 10;
    }
    while (value != 0);
    do
        *s++ = temp[--pos];
    while (pos);
    *s = '\0';
}

static char *UIntToStr(char *s, unsigned value, int numDigits)
{
    char temp[16];
    int pos = 0;
    do
        temp[pos++] = (char)('0' + (value % 10));
    while (value /= 10);
    for (numDigits -= pos; numDigits > 0; numDigits--)
        *s++ = '0';
    do
        *s++ = temp[--pos];
    while (pos);
    *s = '\0';
    return s;
}

static Bool Utf16_To_Utf8(Byte *dest, size_t *destLen, const UInt16 *src, size_t srcLen)
{
    size_t destPos = 0, srcPos = 0;
    for (;;)
    {
        unsigned numAdds;
        UInt32 value;
        if (srcPos == srcLen)
        {
            *destLen = destPos;
            return True;
        }
        value = src[srcPos++];
        if (value < 0x80)
        {
            if (dest)
                dest[destPos] = (char)value;
            destPos++;
            continue;
        }
        if (value >= 0xD800 && value < 0xE000)
        {
            UInt32 c2;
            if (value >= 0xDC00 || srcPos == srcLen)
                break;
            c2 = src[srcPos++];
            if (c2 < 0xDC00 || c2 >= 0xE000)
                break;
            value = (((value - 0xD800) << 10) | (c2 - 0xDC00)) + 0x10000;
        }
        for (numAdds = 1; numAdds < 5; numAdds++)
            if (value < (((UInt32)1) << (numAdds * 5 + 6)))
                break;
        if (dest)
            dest[destPos] = (char)(kUtf8Limits[numAdds - 1] + (value >> (6 * numAdds)));
        destPos++;
        do
        {
            numAdds--;
            if (dest)
                dest[destPos] = (char)(0x80 + ((value >> (6 * numAdds)) & 0x3F));
            destPos++;
        }
        while (numAdds != 0);
    }
    *destLen = destPos;
    return False;
}

static int Buf_EnsureSize(CBuf *dest, size_t size)
{
    if (dest->size >= size)
        return 1;
    Buf_Free(dest, &g_Alloc);
    return Buf_Create(dest, size, &g_Alloc);
}

static SRes Utf16_To_Utf8Buf(CBuf *dest, const UInt16 *src, size_t srcLen)
{
    size_t destLen = 0;
    Bool res;
    Utf16_To_Utf8(NULL, &destLen, src, srcLen);
    destLen += 1;
    if (!Buf_EnsureSize(dest, destLen))
        return SZ_ERROR_MEM;
    res = Utf16_To_Utf8(dest->data, &destLen, src, srcLen);
    dest->data[destLen] = 0;
    return res ? SZ_OK : SZ_ERROR_FAIL;
}

static SRes Utf16_To_Char(CBuf *buf, const UInt16 *s, int fileMode)
{
    int len = 0;
    for (len = 0; s[len] != '\0'; len++);
    
    fileMode = fileMode;
    return Utf16_To_Utf8Buf(buf, s, len);
}

#define PERIOD_4 (4 * 365 + 1)
#define PERIOD_100 (PERIOD_4 * 25 - 1)
#define PERIOD_400 (PERIOD_100 * 4 + 1)

static void ConvertFileTimeToString(const CNtfsFileTime *ft, char *s)
{
    unsigned year, mon, day, hour, min, sec;
    UInt64 v64 = (ft->Low | ((UInt64)ft->High << 32)) / 10000000;
    Byte ms[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    unsigned t;
    UInt32 v;
    sec = (unsigned)(v64 % 60); v64 /= 60;
    min = (unsigned)(v64 % 60); v64 /= 60;
    hour = (unsigned)(v64 % 24); v64 /= 24;
    
    v = (UInt32)v64;
    
    year = (unsigned)(1601 + v / PERIOD_400 * 400);
    v %= PERIOD_400;
    
    t = v / PERIOD_100; if (t ==  4) t =  3; year += t * 100; v -= t * PERIOD_100;
    t = v / PERIOD_4;   if (t == 25) t = 24; year += t * 4;   v -= t * PERIOD_4;
    t = v / 365;        if (t ==  4) t =  3; year += t;       v -= t * 365;
    
    if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0))
        ms[1] = 29;
    for (mon = 1; mon <= 12; mon++)
    {
        unsigned s = ms[mon - 1];
        if (v < s)
            break;
        v -= s;
    }
    day = (unsigned)v + 1;
    s = UIntToStr(s, year, 4); *s++ = '-';
    s = UIntToStr(s, mon, 2);  *s++ = '-';
    s = UIntToStr(s, day, 2);  *s++ = ' ';
    s = UIntToStr(s, hour, 2); *s++ = ':';
    s = UIntToStr(s, min, 2);  *s++ = ':';
    s = UIntToStr(s, sec, 2);
}

static WRes MyCreateDir(const UInt16 *name, const char *destFolder)
{
    CBuf buf;
    Buf_Init(&buf);
    RINOK(Utf16_To_Char(&buf, name, 1));
    
    BOOL folderCreated = [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%s/%s",destFolder,(const char *)buf.data]
                                                   withIntermediateDirectories:YES
                                                                    attributes:nil
                                                                         error:nil];
    
    Buf_Free(&buf, &g_Alloc);
    return folderCreated;
}

static WRes OutFile_OpenUtf16(CSzFile *p, const UInt16 *name, const char *folder)
{
    CBuf buf;
    WRes res;
    Buf_Init(&buf);
    RINOK(Utf16_To_Char(&buf, name, 1));
    const char *pathToOpen = [[NSString stringWithFormat:@"%s/%s",folder,(const char *)buf.data] UTF8String];
    res = OutFile_Open(p, pathToOpen);
    Buf_Free(&buf, &g_Alloc);
    return res;
}
