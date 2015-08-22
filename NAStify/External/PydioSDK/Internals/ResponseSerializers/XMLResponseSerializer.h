//
//  XMLResponseSerializer.h
//  PydioSDK
//
//  Created by ME on 26/01/14.
//  Copyright (c) 2014 MINI. All rights reserved.
//

#import "AFURLResponseSerialization.h"
#import "XMLResponseSerializerDelegate.h"


@interface XMLResponseSerializer : AFXMLParserResponseSerializer
@property (readonly,nonatomic,strong) NSObject<XMLResponseSerializerDelegate> *serializerDelegate;

+(instancetype)serializerWithDelegate:(NSObject<XMLResponseSerializerDelegate>*)delegate;
-(instancetype)initWithDelegate:(NSObject<XMLResponseSerializerDelegate>*)delegate;
@end
