//
//  ConnectionManager.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NetworkConnection.h"
#import "UserAccount.h"
#import "FileItem.h"

typedef enum _BROWSER_ACTION
{
    BROWSER_ACTION_DO_NOTHING = 0,
    BROWSER_ACTION_QUIT_SERVER
} BROWSER_ACTION;


typedef enum _ARCHIVE_TYPE
{
    ARCHIVE_TYPE_ZIP = 0,
    ARCHIVE_TYPE_RAR,
    ARCHIVE_TYPE_TAR,
    ARCHIVE_TYPE_GZ,
    ARCHIVE_TYPE_BZ2,
    ARCHIVE_TYPE_7Z,
    ARCHIVE_TYPE_ACE,
} ARCHIVE_TYPE;

typedef enum _ARCHIVE_COMPRESSION_LEVEL
{
    ARCHIVE_COMPRESSION_LEVEL_NONE = 0,
    ARCHIVE_COMPRESSION_LEVEL_FASTEST,
    ARCHIVE_COMPRESSION_LEVEL_NORMAL,
    ARCHIVE_COMPRESSION_LEVEL_BEST,
} ARCHIVE_COMPRESSION_LEVEL;

typedef enum _SHARING_VALIDITY_UNIT
{
    SHARING_VALIDITY_UNIT_NOT_SUPPORTED = 0,
    SHARING_VALIDITY_UNIT_HOUR,     // 1 hour unit
    SHARING_VALIDITY_UNIT_DAY,      // 1 day unit
} SHARING_VALIDITY_UNIT;

@protocol CMDelegate<NSObject>
- (void)CMFilesList:(NSDictionary *)dict;
- (void)CMRootObject:(NSDictionary *)dict;
@optional
- (void)CMLogin:(NSDictionary *)dict;
- (void)CMLogout:(NSDictionary *)dict;
- (void)CMRequestOTP:(NSDictionary *)dict;
- (void)CMSpaceInfo:(NSDictionary *)dict;
- (void)CMRename:(NSDictionary *)dict;
- (void)CMDeleteProgress:(NSDictionary *)dict;
- (void)CMDeleteFinished:(NSDictionary *)dict;
- (void)CMExtractProgress:(NSDictionary *)dict;
- (void)CMExtractFinished:(NSDictionary *)dict;
- (void)CMCreateFolder:(NSDictionary *)dict;
- (void)CMMoveProgress:(NSDictionary *)dict;
- (void)CMMoveFinished:(NSDictionary *)dict;
- (void)CMCopyProgress:(NSDictionary *)dict;
- (void)CMCopyFinished:(NSDictionary *)dict;
- (void)CMCompressProgress:(NSDictionary *)dict;
- (void)CMCompressFinished:(NSDictionary *)dict;
- (void)CMSearchFinished:(NSDictionary *)dict;
- (void)CMEjectableList:(NSDictionary *)dict;
- (void)CMEjectFinished:(NSDictionary *)dict;
- (void)CMDownloadProgress:(NSDictionary *)dict;
- (void)CMDownloadFinished:(NSDictionary *)dict;
- (void)CMUploadProgress:(NSDictionary *)dict;
- (void)CMUploadFinished:(NSDictionary *)dict;
- (void)CMShareFinished:(NSDictionary *)dict;
- (void)CMShareProgress:(NSDictionary *)dict;
- (void)CMConnectionError:(NSDictionary *)dict;
- (void)CMAction:(NSDictionary *)dict;
- (void)CMCredentialRequest:(NSDictionary *)dict;
@end

@protocol CM<NSObject>
@property(nonatomic,strong) UserAccount *userAccount;
@property(nonatomic,weak) id <CMDelegate> delegate;

- (void)listForPath:(FileItem *)folder;
- (NSArray *)serverInfo;

/* Server features */
- (NSInteger)supportedFeaturesAtPath:(NSString *)path;

@optional
- (BOOL)needLogout;
- (BOOL)login; // Should return YES if we need to wait for login answer to continue with other requests
- (void)sendOTP:(NSString *)otp;
- (BOOL)logout;
- (void)sendOTPEmergencyCode;

- (NSInteger)supportedArchiveType;
- (NSInteger)supportedSharingFeatures;

- (NetworkConnection *)urlForFile:(FileItem *)file;
- (NetworkConnection *)urlForVideo:(FileItem *)file;
- (NetworkConnection *)urlForThumbnail:(FileItem *)file;

- (void)spaceInfoAtPath:(FileItem *)folder;
- (void)deleteFiles:(NSArray *)files;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)ejectFile:(FileItem *)fileItem;
- (void)compressFiles:(NSArray *)files toArchive:(NSString *)archive archiveType:(ARCHIVE_TYPE)archiveType compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel password:(NSString *)password overwrite:(BOOL)overwrite; // files : array of type FileItem
- (void)extractFiles:(NSArray *)files toFolder:(FileItem *)folder withPassword:(NSString *)password overwrite:(BOOL)overwrite extractWithFolder:(BOOL)extractFolders;
- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder;
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password;
- (SHARING_VALIDITY_UNIT)shareValidityUnit;
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localpath;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
- (void)reconnect;
- (void)setCredential:(NSString *)user password:(NSString *)password;
- (BOOL)pluginRespondsToSelector:(SEL)aSelector;

- (void)cancelDeleteTask;
- (void)cancelCopyTask;
- (void)cancelMoveTask;
- (void)cancelCompressTask;
- (void)cancelExtractTask;
- (void)cancelDownloadTask;
- (void)cancelUploadTask;
- (void)cancelSearchTask;
@end

@interface ConnectionManager : NSObject <CM,CMDelegate> {
    id <CM> cmPlugin;
}

@property(nonatomic,strong) UserAccount *userAccount;
@property(nonatomic,weak) id <CMDelegate> delegate;

- (BOOL)pluginRespondsToSelector:(SEL)aSelector;

- (void)listForPath:(FileItem *)folder;
- (NSArray *)serverInfo;
- (BOOL)needLogout;

/* Optional features */
- (BOOL)login;
- (void)sendOTP:(NSString *)otp;
- (BOOL)logout;
- (void)sendOTPEmergencyCode;

- (void)spaceInfoAtPath:(FileItem *)folder;
- (void)deleteFiles:(NSArray *)files;
- (void)renameFile:(FileItem *)oldFile toName:(NSString *)newName atPath:(FileItem *)folder;
- (void)createFolder:(NSString *)folderName inFolder:(FileItem *)folder;
- (void)moveFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)copyFiles:(NSArray *)files toPath:(FileItem *)destFolder andOverwrite:(BOOL)overwrite;
- (void)ejectFile:(FileItem *)fileItem;
- (void)compressFiles:(NSArray *)files toArchive:(NSString *)archive archiveType:(ARCHIVE_TYPE)archiveType compressionLevel:(ARCHIVE_COMPRESSION_LEVEL)compressionLevel password:(NSString *)password overwrite:(BOOL)overwrite;
- (void)extractFiles:(NSArray *)files toFolder:(FileItem *)folder withPassword:(NSString *)password overwrite:(BOOL)overwrite extractWithFolder:(BOOL)extractFolders;
- (void)searchFiles:(NSString *)searchString atPath:(FileItem *)folder;
- (void)shareFiles:(NSArray *)files duration:(NSTimeInterval)duration password:(NSString *)password;
- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localpath;
- (void)uploadLocalFile:(FileItem *)file toPath:(FileItem *)destFolder overwrite:(BOOL)overwrite serverFiles:(NSArray *)filesArray;
- (void)setCredential:(NSString *)user password:(NSString *)password;

- (void)cancelDeleteTask;
- (void)cancelCopyTask;
- (void)cancelMoveTask;
- (void)cancelCompressTask;
- (void)cancelExtractTask;
- (void)cancelDownloadTask;
- (void)cancelUploadTask;
- (void)cancelSearchTask;

- (NetworkConnection *)urlForFile:(FileItem *)file;
- (NetworkConnection *)urlForVideo:(FileItem *)file;
- (NetworkConnection *)urlForThumbnail:(FileItem *)file;

/* Server features */

#define ServerSupportsFeature(feature) \
([self.connectionManager supportedFeaturesAtPath:self.currentFolder.path] & CMSupportedFeaturesMask##feature) == CMSupportedFeaturesMask##feature

typedef NS_OPTIONS(long long, CMSupportedFeaturesMask) {
    CMSupportedFeaturesMaskFileDelete       = 0x0000000000000001,
    CMSupportedFeaturesMaskFolderDelete     = 0x0000000000000002,
    CMSupportedFeaturesMaskFileRename       = 0x0000000000000004,
    CMSupportedFeaturesMaskFolderRename     = 0x0000000000000008,
    CMSupportedFeaturesMaskFileMove         = 0x0000000000000010,
    CMSupportedFeaturesMaskFolderMove       = 0x0000000000000020,
    CMSupportedFeaturesMaskFileCopy         = 0x0000000000000040,
    CMSupportedFeaturesMaskFolderCopy       = 0x0000000000000080,
    CMSupportedFeaturesMaskCompress         = 0x0000000000000100,
    CMSupportedFeaturesMaskExtract          = 0x0000000000000200,
    CMSupportedFeaturesMaskExtractMultiple  = 0x0000000000000400,
    CMSupportedFeaturesMaskEject            = 0x0000000000000800,
    CMSupportedFeaturesMaskQTPlayer         = 0x0000000000001000,
    CMSupportedFeaturesMaskVLCPlayer        = 0x0000000000002000,
    CMSupportedFeaturesMaskVideoSeek        = 0x0000000000004000,
    CMSupportedFeaturesMaskAirPlay          = 0x0000000000008000,
    CMSupportedFeaturesMaskOpenIn           = 0x0000000000010000,
    CMSupportedFeaturesMaskSearch           = 0x0000000000020000,
    CMSupportedFeaturesMaskGoogleCast       = 0x0000000000040000,
    CMSupportedFeaturesMaskFileShare        = 0x0000000000080000,
    CMSupportedFeaturesMaskFolderShare      = 0x0000000000100000,
    CMSupportedFeaturesMaskCacheImage       = 0x0000000000200000,
    CMSupportedFeaturesNone = 0,
};

- (long long)supportedFeaturesAtPath:(NSString *)path;

#define ServerSupportsArchive(archive) \
([self.connectionManager supportedArchiveType] & CMSupportedArchivesMask##archive) == CMSupportedArchivesMask##archive


typedef NS_OPTIONS(NSUInteger, CMSupportedArchivesMask) {
    CMSupportedArchivesNone = 0,
    CMSupportedArchivesMaskZip = (1 << 0),
    CMSupportedArchivesMaskRar = (1 << 1),
    CMSupportedArchivesMaskTar = (1 << 2),
    CMSupportedArchivesMaskGz = (1 << 3),
    CMSupportedArchivesMaskBz2 = (1 << 4),
    CMSupportedArchivesMask7z = (1 << 5),
    CMSupportedArchivesMaskAce = (1 << 6),
    CMSupportedArchivesMaskTarGz = (1 << 7),
    CMSupportedArchivesMaskTarBz2 = (1 << 8),
    CMSupportedArchivesMaskTarXz = (1 << 9),
    CMSupportedArchivesMaskTarLzma = (1 << 10),
    CMSupportedArchivesMaskCpio = (1 << 11),
    CMSupportedArchivesMaskCpioGz = (1 << 12),
    CMSupportedArchivesMaskCpioBz2 = (1 << 13),
    CMSupportedArchivesMaskCpioXz = (1 << 14),
    CMSupportedArchivesMaskCpioLzma = (1 << 15),
    CMSupportedArchivesMaskIso9660 = (1 << 16),
    CMSupportedArchivesAll = (CMSupportedArchivesMaskZip |
                              CMSupportedArchivesMaskRar |
                              CMSupportedArchivesMaskTar |
                              CMSupportedArchivesMaskGz |
                              CMSupportedArchivesMaskBz2 |
                              CMSupportedArchivesMask7z |
                              CMSupportedArchivesMaskAce |
                              CMSupportedArchivesMaskTarGz |
                              CMSupportedArchivesMaskTarBz2 |
                              CMSupportedArchivesMaskTarXz |
                              CMSupportedArchivesMaskTarLzma |
                              CMSupportedArchivesMaskCpio |
                              CMSupportedArchivesMaskCpioGz |
                              CMSupportedArchivesMaskCpioBz2 |
                              CMSupportedArchivesMaskCpioXz |
                              CMSupportedArchivesMaskCpioLzma |
                              CMSupportedArchivesMaskIso9660),
};

- (NSInteger)supportedArchiveType;

/* Sharing supported options */
- (NSInteger)supportedSharingFeatures;

#define ServerSupportsSharingFeature(feature) \
([self.connectionManager supportedSharingFeatures] & CMSupportedSharingMask##feature) == CMSupportedSharingMask##feature


typedef NS_OPTIONS(NSUInteger, CMSupportedSharingMask) {
    CMSupportedSharingNone = 0,
    CMSupportedSharingMaskPassword = (1 << 0),
    CMSupportedSharingMaskValidityPeriod = (1 << 1),
};

/* CMDelegate */
- (void)CMFilesList:(NSDictionary *)dict;
- (void)CMLogin:(NSDictionary *)dict;
- (void)CMLogout:(NSDictionary *)dict;
- (void)CMRequestOTP:(NSDictionary *)dict;
- (void)CMSpaceInfo:(NSDictionary *)dict;
- (void)CMRename:(NSDictionary *)dict;
- (void)CMDeleteProgress:(NSDictionary *)dict;
- (void)CMDeleteFinished:(NSDictionary *)dict;
- (void)CMExtractProgress:(NSDictionary *)dict;
- (void)CMExtractFinished:(NSDictionary *)dict;
- (void)CMCreateFolder:(NSDictionary *)dict;
- (void)CMMoveProgress:(NSDictionary *)dict;
- (void)CMMoveFinished:(NSDictionary *)dict;
- (void)CMCopyProgress:(NSDictionary *)dict;
- (void)CMCopyFinished:(NSDictionary *)dict;
- (void)CMCompressProgress:(NSDictionary *)dict;
- (void)CMCompressFinished:(NSDictionary *)dict;
- (void)CMSearchFinished:(NSDictionary *)dict;
- (void)CMEjectableList:(NSDictionary *)dict;
- (void)CMEjectFinished:(NSDictionary *)dict;
- (void)CMDownloadProgress:(NSDictionary *)dict;
- (void)CMDownloadFinished:(NSDictionary *)dict;
- (void)CMUploadProgress:(NSDictionary *)dict;
- (void)CMUploadFinished:(NSDictionary *)dict;
- (void)CMAction:(NSDictionary *)dict;
- (void)CMConnectionError:(NSDictionary *)dict;
- (void)CMRootObject:(NSDictionary *)dict;
- (void)CMCredentialRequest:(NSDictionary *)dict;
@end
