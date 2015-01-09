//
//  ConnectionManager.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "ConnectionManager.h"
#import "AppDelegate.h"
#import "UserAccount.h"
#import "SBNetworkActivityIndicator.h"

// Import for plugins
#import "CMLocal.h"
#import "CMBox.h"
#import "CMDropbox.h"
#import "CMFreeboxRev.h"
#import "CMFtp.h"
#import "CMGoogleDrive.h"
#import "CMMega.h"
#import "CMOneDrive.h"
#import "CMOwnCloud.h"
#import "CMQnap.h"
#import "CMSamba.h"
#import "CMSynology.h"
#import "CMUPnP.h"
#import "CMWebDav.h"

@implementation ConnectionManager

- (id)init
{
    self = [super init];
    if (self)
    {
        self.userAccount = nil;
    }
    return self;
}

- (id<CM>) idCM
{
    if (!cmPlugin)
    {
        switch (self.userAccount.serverType)
        {
            case SERVER_TYPE_LOCAL:
            {
                cmPlugin = [[CMLocal alloc] init];
                break;
            }
            case SERVER_TYPE_WEBDAV:
            {
                cmPlugin = [[CMWebDav alloc] init];
                break;
            }
            case SERVER_TYPE_FTP:
            case SERVER_TYPE_SFTP:
            {
                cmPlugin = [[CMFtp alloc] init];
                break;
            }
            case SERVER_TYPE_SYNOLOGY:
            {
                cmPlugin = [[CMSynology alloc] init];
                break;
            }
            case SERVER_TYPE_DROPBOX:
            {
                cmPlugin = [[CMDropbox alloc] init];
                break;
            }
            case SERVER_TYPE_FREEBOX_REVOLUTION:
            {
                cmPlugin = [[CMFreeboxRev alloc] init];
                break;
            }
            case SERVER_TYPE_MEGA:
            {
                cmPlugin = [[CMMega alloc] init];
                break;
            }
            case SERVER_TYPE_ONEDRIVE:
            {
                cmPlugin = [[CMOneDrive alloc] init];
                break;
            }
            case SERVER_TYPE_OWNCLOUD:
            {
                cmPlugin = [[CMOwnCloud alloc] init];
                break;
            }
            case SERVER_TYPE_QNAP:
            {
                cmPlugin = [[CMQnap alloc] init];
                break;
            }
//            case SERVER_TYPE_SAMBA:
//            {
//                cmPlugin = [[CMSamba alloc] init];
//                break;
//            }
#ifndef APP_EXTENSION
            case SERVER_TYPE_UPNP:
            {
                cmPlugin = [[CMUPnP alloc] init];
                break;
            }
#endif
            case SERVER_TYPE_BOX:
            {
                cmPlugin = [[CMBox alloc] init];
                break;
            }
            case SERVER_TYPE_GOOGLEDRIVE:
            {
                cmPlugin = [[CMGoogleDrive alloc] init];
                break;
            }
            default:
            {
                break;
            }
        }
        
        cmPlugin.userAccount = self.userAccount;
        cmPlugin.delegate = self;
    }
    return cmPlugin;
}

- (BOOL)pluginRespondsToSelector:(SEL)aSelector
{
    BOOL responds = NO;
    if ([[self idCM] respondsToSelector:aSelector])
    {
        responds = YES;
    }
    return responds;
}

- (void)listForPath:(FileItem *)folder
{
    [[self idCM] listForPath:folder];
}

- (NSArray *)serverInfo
{
    return [[self idCM] serverInfo];
}

- (BOOL)needLogout
{
    return ([[self idCM] respondsToSelector:@selector(logout)]);

}

- (NetworkConnection *)urlForFile:(FileItem *)file
{
    return [[self idCM] urlForFile:file];
}

/* 
 * In some cases, we may need a different building of the url for video streaming
 * if a specific function is declared, call it, elseway fallback to standard function
 */

- (NetworkConnection *)urlForVideo:(FileItem *)file
{
    if ([[self idCM] respondsToSelector:@selector(urlForVideo:)])
    {
        return [[self idCM] urlForVideo:file];
    }
    else
    {
        return [[self idCM] urlForFile:file];
    }
}

#pragma mark -
#pragma mark optional features methods

- (BOOL)login
{
    // This shall return YES if the connection manager needs some
    // information gathered during the login (cookies/session ID/...)
    // to build other requests
    BOOL result = NO;
    if ([[self idCM] respondsToSelector:@selector(login)])
    {
        result = [[self idCM] login];
    }
    return result;
}

- (void)sendOTP:(NSString *)otp;
{
    if ([[self idCM] respondsToSelector:@selector(sendOTP:)])
    {
        [[self idCM] sendOTP:otp];
    }
}

- (BOOL)logout
{
    if ([[self idCM] respondsToSelector:@selector(logout)])
    {
        // Remove network activity indicator if needed
        [[SBNetworkActivityIndicator sharedInstance] removeActivity:[self idCM]];
        
        return [[self idCM] logout];
    }
    else
    {
        return NO;
    }
}

- (void)sendOTPEmergencyCode;
{
    if ([[self idCM] respondsToSelector:@selector(sendOTPEmergencyCode)])
    {
        [[self idCM] sendOTPEmergencyCode];
    }
}

- (void)spaceInfoAtPath:(FileItem *)folder
{
    if ([[self idCM] respondsToSelector:@selector(spaceInfoAtPath:)])
    {
        [[self idCM] spaceInfoAtPath:folder];
    }
}

- (void)deleteFiles:(NSArray *)files
{
    if ([[self idCM] respondsToSelector:@selector(deleteFiles:)])
    {
        [[self idCM] deleteFiles:files];
    }
}

- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder
{
    if ([[self idCM] respondsToSelector:@selector(renameFile:toName:atPath:)])
    {
        [[self idCM] renameFile:oldFile toName:newName atPath:folder];
    }
}

- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder
{
    if ([[self idCM] respondsToSelector:@selector(createFolder:inFolder:)])
    {
        [[self idCM] createFolder:folderName inFolder:folder];
    }
}

- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    if ([[self idCM] respondsToSelector:@selector(moveFiles:toPath:andOverwrite:)])
    {
        [[self idCM] moveFiles:files toPath:destFolder andOverwrite:overwrite];
    }
}

- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite
{
    if ([[self idCM] respondsToSelector:@selector(copyFiles:toPath:andOverwrite:)])
    {
        [[self idCM] copyFiles:files toPath:destFolder andOverwrite:overwrite];
    }
}

- (void)compressFiles:(NSArray *)files
            toArchive:(NSString *)archive
          archiveType:(ARCHIVE_TYPE)archiveType
     compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel
             password:(NSString *)password
            overwrite:(BOOL)overwrite
{
    if ([[self idCM] respondsToSelector:@selector(compressFiles:toArchive:archiveType:compressionLevel:password:overwrite:)])
    {
        [[self idCM] compressFiles:files
                         toArchive:archive
                       archiveType:archiveType
                  compressionLevel:compressionLevel
                          password:password
                         overwrite:overwrite];
    }
}

- (void)extractFiles:(NSArray *)files
            toFolder:(FileItem *)folder
        withPassword:(NSString *)password
           overwrite:(BOOL)overwrite
   extractWithFolder:(BOOL)extractFolders
{
    if ([[self idCM] respondsToSelector:@selector(extractFiles:toFolder:withPassword:overwrite:extractWithFolder:)])
    {
        [[self idCM] extractFiles:files
                         toFolder:folder
                    withPassword:password
                       overwrite:overwrite
               extractWithFolder:extractFolders];
    }
}

- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder
{
    if ([[self idCM] respondsToSelector:@selector(searchFiles:atPath:)])
    {
        [[self idCM] searchFiles:searchString atPath:folder];
    }
}

- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password
{
    if ([[self idCM] respondsToSelector:@selector(shareFiles:duration:password:)])
    {
        [[self idCM] shareFiles:files duration:duration password:password];
    }
}

- (SHARING_VALIDITY_UNIT)shareValidityUnit
{
    if ([[self idCM] respondsToSelector:@selector(shareValidityUnit)])
    {
        return [[self idCM] shareValidityUnit];
    }
    else
    {
        return SHARING_VALIDITY_UNIT_NOT_SUPPORTED;
    }
}

- (void)ejectFile:(FileItem *)fileItem
{
    if ([[self idCM] respondsToSelector:@selector(ejectFile:)])
    {
        [[self idCM] ejectFile:fileItem];
    }
}

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localpath
{
    if ([[self idCM] respondsToSelector:@selector(downloadFile:toLocalName:)])
    {
        [[self idCM] downloadFile:file toLocalName:localpath];
    }
}

- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray
{
    if ([[self idCM] respondsToSelector:@selector(uploadLocalFile:toPath:overwrite:serverFiles:)])
    {
        [[self idCM] uploadLocalFile:file toPath:destFolder overwrite:overwrite serverFiles:filesArray];
    }
}

- (void)reconnect
{
    if ([[self idCM] respondsToSelector:@selector(reconnect)])
    {
        [[self idCM] reconnect];
    }
}

- (void)cancelDeleteTask
{
    [[self idCM] cancelDeleteTask];
}

- (void)cancelCopyTask
{
    [[self idCM] cancelCopyTask];
}

- (void)cancelMoveTask
{
    [[self idCM] cancelMoveTask];
}

- (void)cancelCompressTask
{
    [[self idCM] cancelCompressTask];
}

- (void)cancelExtractTask
{
    [[self idCM] cancelExtractTask];
}

- (void)cancelDownloadTask
{
    [[self idCM] cancelDownloadTask];
}

- (void)cancelUploadTask
{
    [[self idCM] cancelUploadTask];
}

- (void)cancelSearchTask
{
    [[self idCM] cancelSearchTask];
}

#pragma mark -
#pragma mark supported features methods

- (long long)supportedFeaturesAtPath:(NSString *)path
{
    return [[self idCM] supportedFeaturesAtPath:path];
}

- (NSInteger)supportedArchiveType
{
    if ([[self idCM] respondsToSelector:@selector(supportedArchiveType)])
    {
        return [[self idCM] supportedArchiveType];
    }
    else
    {
        return CMSupportedArchivesNone;
    }
}

- (NSInteger)supportedSharingFeatures
{
    if ([[self idCM] respondsToSelector:@selector(supportedSharingFeatures)])
    {
        return [[self idCM] supportedSharingFeatures];
    }
    else
    {
        return CMSupportedSharingNone;
    }
}

#pragma mark -
#pragma mark CMDelegate protocol

- (void)CMFilesList:(NSDictionary *)dict
{
    [self.delegate CMFilesList:dict];
}

- (void)CMRootObject:(NSDictionary *)dict
{
    [self.delegate CMRootObject:dict];
}

- (void)CMLogin:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMLogin:)])
    {
        [self.delegate CMLogin:dict];
    }
}

- (void)CMLogout:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMLogout:)])
    {
        [self.delegate CMLogout:dict];
    }
}

- (void)CMRequestOTP:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMRequestOTP:)])
    {
        [self.delegate CMRequestOTP:dict];
    }
}

- (void)CMSpaceInfo:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMSpaceInfo:)])
    {
        [self.delegate CMSpaceInfo:dict];
    }
}

- (void)CMRename:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMRename:)])
    {
        [self.delegate CMRename:dict];
    }
}

- (void)CMDeleteProgress:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMDeleteProgress:)])
    {
        [self.delegate CMDeleteProgress:dict];
    }
}

- (void)CMDeleteFinished:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMDeleteFinished:)])
    {
        [self.delegate CMDeleteFinished:dict];
    }
}

- (void)CMExtractProgress:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMExtractProgress:)])
    {
        [self.delegate CMExtractProgress:dict];
    }
}

- (void)CMExtractFinished:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMExtractFinished:)])
    {
        [self.delegate CMExtractFinished:dict];
    }
}

- (void)CMCreateFolder:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMCreateFolder:)])
    {
        [self.delegate CMCreateFolder:dict];
    }
}

- (void)CMMoveProgress:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMMoveProgress:)])
    {
        [self.delegate CMMoveProgress:dict];
    }
}

- (void)CMMoveFinished:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMMoveFinished:)])
    {
        [self.delegate CMMoveFinished:dict];
    }
}

- (void)CMCopyProgress:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMCopyProgress:)])
    {
        [self.delegate CMCopyProgress:dict];
    }
}

- (void)CMCopyFinished:(NSDictionary *)dict;
{
    if ([self.delegate respondsToSelector:@selector(CMCopyFinished:)])
    {
        [self.delegate CMCopyFinished:dict];
    }
}

- (void)CMCompressProgress:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMCompressProgress:)])
    {
        [self.delegate CMCompressProgress:dict];
    }
}

- (void)CMCompressFinished:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMCompressFinished:)])
    {
        [self.delegate CMCompressFinished:dict];
    }
}

- (void)CMSearchFinished:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMSearchFinished:)])
    {
        [self.delegate CMSearchFinished:dict];
    }
}

- (void)CMShareProgress:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMShareProgress:)])
    {
        [self.delegate CMShareProgress:dict];
    }
}

- (void)CMShareFinished:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMShareFinished:)])
    {
        [self.delegate CMShareFinished:dict];
    }
}

- (void)CMEjectableList:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMEjectableList:)])
    {
        [self.delegate CMEjectableList:dict];
    }
}

- (void)CMEjectFinished:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMEjectFinished:)])
    {
        [self.delegate CMEjectFinished:dict];
    }
}

- (void)CMDownloadProgress:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMDownloadProgress:)])
    {
        [self.delegate CMDownloadProgress:dict];
    }
}

- (void)CMDownloadFinished:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMDownloadFinished:)])
    {
        [self.delegate CMDownloadFinished:dict];
    }
}

- (void)CMUploadProgress:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMUploadProgress:)])
    {
        [self.delegate CMUploadProgress:dict];
    }
}

- (void)CMUploadFinished:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMUploadFinished:)])
    {
        [self.delegate CMUploadFinished:dict];
    }
}

- (void)CMAction:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMAction:)])
    {
        [self.delegate CMAction:dict];
    }
}

- (void)CMConnectionError:(NSDictionary *)dict
{
    if ([self.delegate respondsToSelector:@selector(CMConnectionError:)])
    {
        [self.delegate CMConnectionError:dict];
    }
}

@end
