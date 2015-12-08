//
//  FileItem.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "FileItem.h"


@implementation FileItem

- (FILETYPE) fileType
{
    FILETYPE fileType = FILETYPE_UNKNOWN;
    
    if (self.isDir)
    {
        fileType = FILETYPE_FOLDER;
	}
    else if (self.isCompressed)
    {
		fileType = FILETYPE_ARCHIVE;
    }
    else if (([[self.type lowercaseString] isEqualToString:@"mp4"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m4v"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mov"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mpv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"3gp"]))
    {
        fileType = FILETYPE_QT_VIDEO;
    }
    else if (([[self.type lowercaseString] isEqualToString:@"mp3"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m4a"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m4b"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m4p"]) ||
             ([[self.type lowercaseString] isEqualToString:@"caf"]) ||
             ([[self.type lowercaseString] isEqualToString:@"aifc"]) ||
             ([[self.type lowercaseString] isEqualToString:@"aiff"]) ||
             ([[self.type lowercaseString] isEqualToString:@"aif"]) ||
             ([[self.type lowercaseString] isEqualToString:@"wav"]) ||
             ([[self.type lowercaseString] isEqualToString:@"snd"]) ||
             ([[self.type lowercaseString] isEqualToString:@"au"]) ||
             ([[self.type lowercaseString] isEqualToString:@"amr"])
             )
    {
        fileType = FILETYPE_QT_AUDIO;
    }
    else if (([[self.type lowercaseString] isEqualToString:@"3gp2"]) ||
             ([[self.type lowercaseString] isEqualToString:@"3gpp"]) ||
             ([[self.type lowercaseString] isEqualToString:@"amv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"asf"]) ||
             ([[self.type lowercaseString] isEqualToString:@"avi"]) ||
             ([[self.type lowercaseString] isEqualToString:@"axv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"divx"]) ||
             ([[self.type lowercaseString] isEqualToString:@"dv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"flv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"f4v"]) ||
             ([[self.type lowercaseString] isEqualToString:@"gvi"]) ||
             ([[self.type lowercaseString] isEqualToString:@"gxf"]) ||
             ([[self.type lowercaseString] isEqualToString:@"iso"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m1v"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m2p"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m2t"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m2ts"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m2v"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m3u8"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mks"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mkv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"moov"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mp2v"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mpeg"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mpeg1"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mpeg2"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mpeg4"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mpg"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mt2s"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mts"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mxf"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mxg"]) ||
             ([[self.type lowercaseString] isEqualToString:@"nsv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"nuv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"oga"]) ||
             ([[self.type lowercaseString] isEqualToString:@"ogg"]) ||
             ([[self.type lowercaseString] isEqualToString:@"ogm"]) ||
             ([[self.type lowercaseString] isEqualToString:@"ogv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"ogx"]) ||
             ([[self.type lowercaseString] isEqualToString:@"spx"]) ||
             ([[self.type lowercaseString] isEqualToString:@"ps"]) ||
             ([[self.type lowercaseString] isEqualToString:@"qt"]) ||
             ([[self.type lowercaseString] isEqualToString:@"rec"]) ||
             ([[self.type lowercaseString] isEqualToString:@"rm"]) ||
             ([[self.type lowercaseString] isEqualToString:@"rmvb"]) ||
             ([[self.type lowercaseString] isEqualToString:@"rtsp"]) ||
             ([[self.type lowercaseString] isEqualToString:@"tod"]) ||
             ([[self.type lowercaseString] isEqualToString:@"ts"]) ||
             ([[self.type lowercaseString] isEqualToString:@"tts"]) ||
             ([[self.type lowercaseString] isEqualToString:@"vob"]) ||
             ([[self.type lowercaseString] isEqualToString:@"vro"]) ||
             ([[self.type lowercaseString] isEqualToString:@"webm"]) ||
             ([[self.type lowercaseString] isEqualToString:@"wm"]) ||
             ([[self.type lowercaseString] isEqualToString:@"wmv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"wtv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"xesc"]) ||
             ([[self.type lowercaseString] isEqualToString:@"img"]))
    {
        
        fileType = FILETYPE_VLC_VIDEO;
    }
    else if (([[self.type lowercaseString] isEqualToString:@"aac"]) ||
             ([[self.type lowercaseString] isEqualToString:@"aob"]) ||
             ([[self.type lowercaseString] isEqualToString:@"ape"]) ||
             ([[self.type lowercaseString] isEqualToString:@"axa"]) ||
             ([[self.type lowercaseString] isEqualToString:@"flac"]) ||
             ([[self.type lowercaseString] isEqualToString:@"it"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m2a"]) ||
             ([[self.type lowercaseString] isEqualToString:@"m4b"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mka"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mlp"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mod"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mp1"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mp2"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mpa"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mpc"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mpga"]) ||
             ([[self.type lowercaseString] isEqualToString:@"oga"]) ||
             ([[self.type lowercaseString] isEqualToString:@"ogg"]) ||
             ([[self.type lowercaseString] isEqualToString:@"oma"]) ||
             ([[self.type lowercaseString] isEqualToString:@"opus"]) ||
             ([[self.type lowercaseString] isEqualToString:@"rmi"]) ||
             ([[self.type lowercaseString] isEqualToString:@"s3m"]) ||
             ([[self.type lowercaseString] isEqualToString:@"spx"]) ||
             ([[self.type lowercaseString] isEqualToString:@"tta"]) ||
             ([[self.type lowercaseString] isEqualToString:@"voc"]) ||
             ([[self.type lowercaseString] isEqualToString:@"vqf"]) ||
             ([[self.type lowercaseString] isEqualToString:@"w64"]) ||
             ([[self.type lowercaseString] isEqualToString:@"wma"]) ||
             ([[self.type lowercaseString] isEqualToString:@"wv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"xa"]) ||
             ([[self.type lowercaseString] isEqualToString:@"xm"]))
    {
        fileType = FILETYPE_VLC_AUDIO;
	}
    else if (
             ([[self.type lowercaseString] isEqualToString:@"3fr"]) ||
             ([[self.type lowercaseString] isEqualToString:@"arw"]) ||
             ([[self.type lowercaseString] isEqualToString:@"bmp"]) ||
             ([[self.type lowercaseString] isEqualToString:@"cr2"]) ||
             ([[self.type lowercaseString] isEqualToString:@"crw"]) ||
             ([[self.type lowercaseString] isEqualToString:@"cur"]) ||
             ([[self.type lowercaseString] isEqualToString:@"dcr"]) ||
             ([[self.type lowercaseString] isEqualToString:@"dng"]) ||
             ([[self.type lowercaseString] isEqualToString:@"png"]) ||
             ([[self.type lowercaseString] isEqualToString:@"exr"]) ||
             ([[self.type lowercaseString] isEqualToString:@"fpx"]) ||
             ([[self.type lowercaseString] isEqualToString:@"fpix"]) ||
             ([[self.type lowercaseString] isEqualToString:@"gif"]) ||
             ([[self.type lowercaseString] isEqualToString:@"hdr"]) ||
             ([[self.type lowercaseString] isEqualToString:@"jpg"]) ||
             ([[self.type lowercaseString] isEqualToString:@"jpeg"]) ||
             ([[self.type lowercaseString] isEqualToString:@"kdc"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mac"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mos"]) ||
             ([[self.type lowercaseString] isEqualToString:@"mrw"]) ||
             ([[self.type lowercaseString] isEqualToString:@"nef"]) ||
             ([[self.type lowercaseString] isEqualToString:@"nrw"]) ||
             ([[self.type lowercaseString] isEqualToString:@"orf"]) ||
             ([[self.type lowercaseString] isEqualToString:@"pnt"]) ||
             ([[self.type lowercaseString] isEqualToString:@"ppm"]) ||
             ([[self.type lowercaseString] isEqualToString:@"psd"]) ||
             ([[self.type lowercaseString] isEqualToString:@"ptng"]) ||
             ([[self.type lowercaseString] isEqualToString:@"qti"]) ||
             ([[self.type lowercaseString] isEqualToString:@"qtif"]) ||
             ([[self.type lowercaseString] isEqualToString:@"raf"]) ||
             ([[self.type lowercaseString] isEqualToString:@"raw"]) ||
             ([[self.type lowercaseString] isEqualToString:@"sgi"]) ||
             ([[self.type lowercaseString] isEqualToString:@"sr2"]) ||
             ([[self.type lowercaseString] isEqualToString:@"srf"]) ||
             ([[self.type lowercaseString] isEqualToString:@"targa"]) ||
             ([[self.type lowercaseString] isEqualToString:@"tga"]) ||
             ([[self.type lowercaseString] isEqualToString:@"tif"]) ||
             ([[self.type lowercaseString] isEqualToString:@"x3f"]) ||
             ([[self.type lowercaseString] isEqualToString:@"xbm"]))
    {
		fileType = FILETYPE_PHOTO;
	}
    else if ([[self.type lowercaseString] isEqualToString:@"pdf"])
    {
		fileType = FILETYPE_PDF;
    }
    else if (([[self.type lowercaseString] isEqualToString:@"csv"]) ||
             ([[self.type lowercaseString] isEqualToString:@"rtf"]) ||
             ([[self.type lowercaseString] isEqualToString:@"html"]) ||
             ([[self.type lowercaseString] isEqualToString:@"xls"]) ||
             ([[self.type lowercaseString] isEqualToString:@"xlsx"]) ||
             ([[self.type lowercaseString] isEqualToString:@"doc"]) ||
             ([[self.type lowercaseString] isEqualToString:@"docx"]) ||
             ([[self.type lowercaseString] isEqualToString:@"ppt"]) ||
             ([[self.type lowercaseString] isEqualToString:@"pptx"]) ||
             ([[self.type lowercaseString] isEqualToString:@"pages"]) ||
             ([[self.type lowercaseString] isEqualToString:@"numbers"]) ||
             ([[self.type lowercaseString] isEqualToString:@"keynote"]) ||
             ([[self.type lowercaseString] isEqualToString:@"txt"]))
    {
		fileType = FILETYPE_TEXT;
    }
    return fileType;
}

- (UIImage *)image
{
    UIImage *imageForFile = nil;
    switch ([self fileType])
    {
		case FILETYPE_FOLDER:
        {
			imageForFile = [UIImage imageNamed:@"folder.png"];
			break;
        }
		default :
        {
            imageForFile = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png",[self.type lowercaseString]]];
            if (!imageForFile)
            {
                imageForFile = [UIImage imageNamed:@"unknown.png"];
            }
			break;
        }
	}
    return imageForFile;
}

#if TARGET_OS_TV
- (NSURL *)urlForImage
{
    NSURL *url = nil;
    switch ([self fileType])
    {
        case FILETYPE_FOLDER:
        {
            url = [[NSBundle mainBundle]
                            URLForResource: @"folder" withExtension:@"png"];
            break;
        }
        default :
        {
            url = [[NSBundle mainBundle]
                   URLForResource: [self.type lowercaseString] withExtension:@"png"];
            if (!url)
            {
                url = [[NSBundle mainBundle]
                       URLForResource: @"unknown" withExtension:@"png"];
            }
            break;
        }
    }
    return url;
}
#endif

- (NSString *)description
{
    NSMutableString *description = [NSMutableString string];
    if (self.isDir)
    {
        [description appendString:@"Folder"];
	}
    else if (self.isCompressed)
    {
        [description appendFormat:@"Archive (%@)",self.type];
    }
    else
    {
        [description appendFormat:@"File (%@)",self.type];
    }

    [description appendFormat:@" %@",self.name];
    [description appendFormat:@" shortPath %@",self.shortPath];
    [description appendFormat:@" path %@",self.path];

    
    return description;
}

- (id)copyWithZone:(NSZone *)zone
{
    FileItem *copy = [[[self class] alloc] init];
    copy.name = [self.name copyWithZone:zone];
    copy.shortPath = [self.shortPath copyWithZone:zone];
    copy.path = [self.path copyWithZone:zone];
    copy.fullPath = [self.fullPath copyWithZone:zone];
    copy.type = [self.type copyWithZone:zone];
    copy.fileSize = [self.fileSize copyWithZone:zone];
    copy.fileSizeNumber = [self.fileSizeNumber copyWithZone:zone];
    copy.fileDate = [self.fileDate copyWithZone:zone];
    copy.fileDateNumber = [self.fileDateNumber copyWithZone:zone];
    copy.owner = [self.owner copyWithZone:zone];
    copy.ejectName = [self.ejectName copyWithZone:zone];
    copy.objectIds = [self.objectIds copyWithZone:zone];
    copy.isCompressed = self.isCompressed;
    copy.isDir = self.isDir;
    copy.isEjectable = self.isEjectable;
    copy.writeAccess = self.writeAccess;
    return copy;
}

@end
