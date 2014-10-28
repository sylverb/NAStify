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
} URLTYPE;

@interface NetworkConnection : NSObject
{
}

@property (nonatomic) URLTYPE urlType;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSMutableDictionary *requestCookies;
@property (nonatomic, strong) NSMutableDictionary *requestHeaders;
@property (nonatomic, strong) NSMutableDictionary *postRequestParams;

-(BOOL) isFileURL;

@end
