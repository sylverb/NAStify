//
//  XMLResponseSerializerDelegate.h
//  PydioSDK
//
//  Created by ME on 26/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol XMLResponseSerializerDelegate <NSObject>
@required
-(id <NSXMLParserDelegate>)xmlParserDelegate;
-(id)parseResult;
-(NSDictionary*)errorUserInfo:(id)response;
@end


@interface LoginResponseSerializerDelegate : NSObject<XMLResponseSerializerDelegate>

@end

@interface NotAuthorizedResponseSerializerDelegate : NSObject<XMLResponseSerializerDelegate>

@end

@interface ErrorResponseSerializerDelegate : NSObject<XMLResponseSerializerDelegate>

@end


@interface WorkspacesResponseSerializerDelegate : NSObject<XMLResponseSerializerDelegate>

@end

@interface ListFilesResponseSerializerDelegate : NSObject<XMLResponseSerializerDelegate>

@end

@interface SuccessResponseSerializerDelegate : NSObject<XMLResponseSerializerDelegate>

-(instancetype)initWithAction:(NSString*)name;
@end
