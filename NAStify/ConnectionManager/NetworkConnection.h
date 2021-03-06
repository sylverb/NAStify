//
//  NetworkConnection.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef enum _URLTYPE
{
    URLTYPE_LOCAL,
    URLTYPE_HTTP,
    URLTYPE_HTTP_POST,
    URLTYPE_FTP,
    URLTYPE_SMB,
} URLTYPE;

@interface NetworkConnection : NSObject
{
}

@property (nonatomic) URLTYPE urlType;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSMutableDictionary *requestCookies;
@property (nonatomic, strong) NSMutableDictionary *requestHeaders;
@property (nonatomic, strong) NSMutableDictionary *postRequestParams;
@property (nonatomic, strong) NSString *workgroup;
@property (nonatomic, strong) NSString *user;
@property (nonatomic, strong) NSString *password;

-(BOOL) isFileURL;

@end
