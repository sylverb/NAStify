//
//  UserAccount.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import "UserAccount.h"
#if !defined(APP_EXTENSION) && TARGET_OS_IOS
#import "MKStoreKit.h"
#endif

@implementation UserAccount

- (id)init
{
    self = [super init];
    if (self)
    {
        self.uuid = [NSString generateUUID];
        self.accountName = nil;
        self.serverType = SERVER_TYPE_UNKNOWN;
        self.authenticationType = AUTHENTICATION_TYPE_UNKNOWN;
        self.server = nil;
        self.port = nil;
        self.userName = nil;
        self.boolSSL = NO;
        self.acceptUntrustedCertificate = YES;
        self.encoding = nil;
        self.transfertMode = 0;
        self.settings = [[NSDictionary alloc] init];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self)
    {
        self.uuid =  [coder decodeObjectForKey:@"uuid"];
        self.accountName = [coder decodeObjectForKey:@"accountName"];
        self.serverType = [coder decodeIntForKey:@"serverType"];
        self.authenticationType = [coder decodeIntForKey:@"authenticationType"];
        self.server = [coder decodeObjectForKey:@"server"];
        self.port = [coder decodeObjectForKey:@"port"];
        self.userName = [coder decodeObjectForKey:@"userName"];
        self.boolSSL = [coder decodeBoolForKey:@"boolSSL"];
        self.acceptUntrustedCertificate = [coder decodeBoolForKey:@"acceptUntrustedCertificate"];
        self.encoding = [coder decodeObjectForKey:@"encoding"];
        self.transfertMode = [coder decodeIntForKey:@"transfertMode"];
        if ([coder decodeObjectForKey:@"settings"])
        {
            self.settings = [coder decodeObjectForKey:@"settings"];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.uuid forKey:@"uuid"];
    [coder encodeObject:self.accountName forKey:@"accountName"];
    [coder encodeInt:self.serverType forKey:@"serverType"];
    [coder encodeInt:self.authenticationType forKey:@"authenticationType"];
    [coder encodeObject:self.server forKey:@"server"];
    [coder encodeObject:self.port forKey:@"port"];
    [coder encodeObject:self.userName forKey:@"userName"];
    [coder encodeBool:self.boolSSL forKey:@"boolSSL"];
    [coder encodeBool:self.acceptUntrustedCertificate forKey:@"acceptUntrustedCertificate"];
    [coder encodeObject:self.encoding forKey:@"encoding"];
    [coder encodeInt:self.transfertMode forKey:@"transfertMode"];
    [coder encodeObject:self.settings forKey:@"settings"];
}

- (id)copyWithZone:(NSZone *)zone
{
    UserAccount *copy = [[[self class] allocWithZone: zone] init];
    copy.uuid = self.uuid;
    copy.accountName = self.accountName;
    copy.serverType = self.serverType;
    copy.authenticationType = self.authenticationType;
    copy.server = self.server;
    copy.port = self.port;
    copy.userName = self.userName;
    copy.boolSSL = self.boolSSL;
    copy.acceptUntrustedCertificate = self.acceptUntrustedCertificate;
    copy.encoding = self.encoding;
    copy.transfertMode = self.transfertMode;
    copy.settings = [self.settings copyWithZone:zone];
    return copy;
}

- (BOOL)shouldShowAds
{
#if !defined(APP_EXTENSION) && TARGET_OS_IOS
    if ([[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads"])
    {
        return FALSE;
    }
    BOOL showAds = TRUE;
    switch (self.serverType)
    {
        case SERVER_TYPE_BOX:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_box"];
            break;
        }
        case SERVER_TYPE_DROPBOX:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_dropbox"];
            break;
        }
        case SERVER_TYPE_FREEBOX_REVOLUTION:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_freebox"];
            break;
        }
        case SERVER_TYPE_FTP:
        case SERVER_TYPE_SFTP:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_ftp"];
            break;
        }
        case SERVER_TYPE_GOOGLEDRIVE:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_googledrive"];
            break;
        }
        case SERVER_TYPE_LOCAL:
        {
            showAds = FALSE;
            break;
        }
        case SERVER_TYPE_MEGA:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_mega"];
            break;
        }
        case SERVER_TYPE_ONEDRIVE:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_onedrive"];
            break;
        }
        case SERVER_TYPE_OWNCLOUD:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_owncloud"];
            break;
        }
        case SERVER_TYPE_QNAP:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_qnap"];
            break;
        }
        case SERVER_TYPE_SYNOLOGY:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_synology"];
            break;
        }
        case SERVER_TYPE_UPNP:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_upnp"];
            break;
        }
        case SERVER_TYPE_WEBDAV:
        {
            showAds = ![[MKStoreKit sharedKit] isProductPurchased:@"com.sylver.NAStify.no_ads_webdav"];
            break;
        }
        default:
        {
            break;
        }
    }
    return showAds;
#else
    // No ads on document provider or AppleTV
    return FALSE;
#endif
}

@end
