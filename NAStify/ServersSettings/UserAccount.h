//
//  UserAccount.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum _SERVER_TYPE
{
    SERVER_TYPE_UNKNOWN = 0,        // For initial setup
    SERVER_TYPE_LOCAL,              // For local files
    SERVER_TYPE_WEBDAV,             // For WebDAV servers
    SERVER_TYPE_FTP,                // For FTP/FTPS servers
    SERVER_TYPE_SYNOLOGY,           // Synology's File Station protocol
    SERVER_TYPE_DROPBOX,            // Dropbox
    SERVER_TYPE_FREEBOX_REVOLUTION, // Freebox revolution
    SERVER_TYPE_QNAP,               // QNAP Web file manager protocol
    SERVER_TYPE_SAMBA,              // Windows shares
    SERVER_TYPE_UPNP,               // UPnP servers
    SERVER_TYPE_SFTP,               // For SFTP servers
    SERVER_TYPE_BOX,                // Box ( https://github.com/box/box-ios-sdk-v2 )
    SERVER_TYPE_GOOGLEDRIVE,        // Google drive ( https://code.google.com/p/google-api-objectivec-client/ )
    SERVER_TYPE_OWNCLOUD,           // Own Cloud ( https://github.com/owncloud/ios-library )
    SERVER_TYPE_ONEDRIVE,           // Microsoft OneDrive ( https://github.com/liveservices/LiveSDK-for-iOS )
    SERVER_TYPE_MEGA,               // Mega ( https://github.com/meganz/sdk )
//    SERVER_TYPE_SUGARSYNC,          // SugarSync ( https://github.com/huadee/sugarsync-ios )
//    SERVER_TYPE_NFS,                // NFS ( https://github.com/sahlberg/libnfs )
//    SERVER_TYPE_CLOUDDRIVE,         // Amazon cloud drive ( https://developer.amazon.com/public/apis/experience/cloud-drive )
//    SERVER_TYPE_AMAZONS3            // Amazon S3 ( https://github.com/aws/aws-sdk-ios )
//    SERVER_TYPE_ICLOUD,             // Apple iCloud ( https://developer.apple.com/icloud/index.html )
//    SERVER_TYPE_OPENSTACK,          // OpenStack
//    SERVER_TYPE_HUBIC,              // hubiC
//    SERVER_TYPE_KUAIPAN,
//    SERVER_TYPE_BAIDU,              // Baidu ( http://developer.baidu.com/en/ )
//    SERVER_TYPE_THECUS,
//    SERVER_TYPE_DLINK,
//    SERVER_TYPE_NETGEAR,
//    SERVER_TYPE_VEHOTECH,
//    SERVER_TYPE_WESTERNDIGITAL,
//    SERVER_TYPE_ZYXEL,
//    SERVER_TYPE_SEAGATE,
//    SERVER_TYPE_BUFFALO,
//    SERVER_TYPE_IOMEGA,
//    SERVER_TYPE_LACIE,
//    SERVER_TYPE_DANE-ELEC,
//    SERVER_TYPE_LINKSYS,
//    SERVER_TYPE_PLEXTOR,
} SERVER_TYPE;

typedef enum _AUTHENTICATION_TYPE
{
    AUTHENTICATION_TYPE_UNKNOWN = 0,
    AUTHENTICATION_TYPE_PASSWORD,
    AUTHENTICATION_TYPE_TOKEN,
    AUTHENTICATION_TYPE_2STEP,
    AUTHENTICATION_TYPE_CERTIFICATE
} AUTHENTICATION_TYPE;

typedef enum _TRANSFERT_MODE
{
    TRANSFERT_MODE_FTP_PASSIVE = 0,
    TRANSFERT_MODE_FTP_ACTIVE
} TRANSFERT_MODE;

@interface UserAccount : NSObject<NSCoding>

@property(nonatomic, strong) NSString *uuid;
@property(nonatomic, strong) NSString *accountName;
@property(nonatomic, strong) NSString *server;
@property(nonatomic, strong) id serverObject; // To pass complex server (UPnP,...)
@property(nonatomic, strong) NSString *port;
@property(nonatomic) SERVER_TYPE serverType;
@property(nonatomic) AUTHENTICATION_TYPE authenticationType;
@property(nonatomic, strong) NSString *userName;
/* Character enconding on server */
@property(nonatomic, strong) NSString *encoding;
/* Transfert mode (for FTP) */
@property(nonatomic) TRANSFERT_MODE transfertMode;
@property(nonatomic, strong) NSDictionary *settings;

@property(nonatomic) BOOL boolSSL;
@property(nonatomic) BOOL acceptUntrustedCertificate;

- (BOOL)shouldShowAds;

@end
