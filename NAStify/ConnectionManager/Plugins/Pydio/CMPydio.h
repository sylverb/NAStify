//
//  CMPydio.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2015 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionManager.h"
#import "UserAccount.h"

#import "SBNetworkActivityIndicator.h"

@interface CMPydio : NSObject <CM,UIAlertViewDelegate> {
}


@property(nonatomic, strong) UserAccount *userAccount;
@property(nonatomic, weak)   id <CMDelegate> delegate;
@property(nonatomic, strong) NSArray *workspaces;

- (NSArray *)serverInfo;
- (BOOL)login;
- (void)listForPath:(FileItem *)folder;

- (void)downloadFile:(FileItem *)file toLocalName:(NSString *)localName;
- (void)cancelDownloadTask;

/* File URL requests */
- (NetworkConnection *)urlForFile:(FileItem *)file;

/* Server features */
- (long long)supportedFeaturesAtPath:(NSString *)path;

@end
