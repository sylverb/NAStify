//
//  XMLResponseSerializer.m
//  PydioSDK
//
//  Created by ME on 26/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "XMLResponseSerializer.h"
#import "PydioErrors.h"


@implementation XMLResponseSerializer

+(instancetype)serializerWithDelegate:(NSObject<XMLResponseSerializerDelegate>*)delegate {
    XMLResponseSerializer *serializer = [[XMLResponseSerializer alloc] initWithDelegate:delegate];
    
    return serializer;
}

-(instancetype)initWithDelegate:(NSObject<XMLResponseSerializerDelegate>*)delegate {
    self = [super init];
    if (self) {
        _serializerDelegate = delegate;
    }
    
    return self;
}

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    id responseObject = [super responseObjectForResponse:response data:data error:error];
    if (!responseObject) {
        return nil;
    }
    
    NSXMLParser *parser = (NSXMLParser *)responseObject;
    [parser setDelegate:[self.serializerDelegate xmlParserDelegate]];
    [parser parse];
    
    id result = [self.serializerDelegate parseResult];
    if (result) {
        return result;
    }
    
    NSDictionary *userInfo = [self.serializerDelegate errorUserInfo:responseObject];
    
    if (error && userInfo) {
        *error = [[NSError alloc] initWithDomain:PydioErrorDomain code:PydioErrorUnableToParseAnswer userInfo:userInfo];
    }
    
    return nil;
}

@end
