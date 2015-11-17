//
//  CMUPnP.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"

#import "AFNetworking.h"
#import "SBNetworkActivityIndicator.h"
#import "MediaServerBasicObjectParser.h"
#import "MediaServer1ItemObject.h"
#import "MediaServer1ContainerObject.h"
#import "MediaServer1Device.h"

@interface CMUPnP : NSObject <CM> {
    /* generic data storage */
    NSString *_listTitle;
    NSArray *_objectList;
    NSMutableArray *_mutableObjectList;
    
    /* UPNP specifics */
    MediaServer1Device *_UPNPdevice;
    NSString *_UPNProotID;
    
    /* Download operation */
    AFHTTPRequestOperationManager *_manager;
    AFHTTPRequestOperation *_downloadOperation;
}


@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;

- (NSArray *)serverInfo;
- (void)listForPath:(FileItem *)folder;

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName;
- (void)cancelDownloadTask;

/* File URL requests */
- (NetworkConnection *)urlForFile:(FileItem *)file;
- (NetworkConnection *)urlForThumbnail:(FileItem *)file;

/* Server features */
- (long long)supportedFeaturesAtPath:(NSString *)path;

@end
