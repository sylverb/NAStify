
#import "LoginResponse.h"
#import "NotAuthorizedResponse.h"
#import "PydioErrorResponse.h"
#import "PydioSuccessResponse.h"

#import "XMLResponseSerializerDelegate.h"
#import "LoginResponseParserDelegate.h"
#import "NotAuthorizedResponseParserDelegate.h"
#import "RepositoriesParserDelegate.h"
#import "ListFilesResponseParserDelegate.h"
#import "SuccessResponseParserDelegate.h"
#import "ErrorResponseParserDelegate.h"



#pragma mark - Login response

@interface LoginResponseSerializerDelegate ()
@property (nonatomic,strong) LoginResponseParserDelegate* parserDelegate;
@end

@implementation LoginResponseSerializerDelegate

-(instancetype)init {
    self = [super init];
    if (self) {
        self.parserDelegate = [[LoginResponseParserDelegate alloc] init];
    }
    
    return self;
}

-(id <NSXMLParserDelegate>)xmlParserDelegate {
    return self.parserDelegate;
}

-(id)parseResult {
    LoginResponse *result = nil;
    if (self.parserDelegate.resultValue) {
        result = [[LoginResponse alloc] initWithValue:self.parserDelegate.resultValue AndToken:self.parserDelegate.secureToken];
    }
    
    return result;
}

-(NSDictionary*)errorUserInfo:(id)response {
    return @{
             NSLocalizedDescriptionKey : NSLocalizedStringFromTable(@"Error when parsing login response", nil, @"PydioSDK"),
             NSLocalizedFailureReasonErrorKey : [NSString stringWithFormat:NSLocalizedStringFromTable(@"Could not extract login result value from: %@", nil, @"PydioSDK"), response]
             };
}

@end

#pragma mark - Not Authorized response

@interface NotAuthorizedResponseSerializerDelegate ()
@property (nonatomic,strong) NotAuthorizedResponseParserDelegate* parserDelegate;
@end

@implementation NotAuthorizedResponseSerializerDelegate

-(instancetype)init {
    self = [super init];
    if (self) {
        self.parserDelegate = [[NotAuthorizedResponseParserDelegate alloc] init];
    }
    
    return self;
}

-(id <NSXMLParserDelegate>)xmlParserDelegate {
    return self.parserDelegate;
}

-(id)parseResult {
    NotAuthorizedResponse *result = nil;
    if (self.parserDelegate.notLogged) {
        result = [[NotAuthorizedResponse alloc] init];
    }
    
    return result;
}

-(NSDictionary*)errorUserInfo:(id)response {
    return nil;
}

@end

#pragma mark - Error Response

@interface ErrorResponseSerializerDelegate ()
@property (nonatomic,strong) ErrorResponseParserDelegate* parserDelegate;
@end

@implementation ErrorResponseSerializerDelegate

-(instancetype)init {
    self = [super init];
    if (self) {
        self.parserDelegate = [[ErrorResponseParserDelegate alloc] init];
    }
    
    return self;
}

-(id <NSXMLParserDelegate>)xmlParserDelegate {
    return self.parserDelegate;
}

-(id)parseResult {
    PydioErrorResponse *result = nil;
    if (self.parserDelegate.errorMessage) {
        result = [PydioErrorResponse errorResponseWithString:self.parserDelegate.errorMessage];
    }
    
    return result;
}

-(NSDictionary*)errorUserInfo:(id)response {
    return nil;
}

@end

#pragma mark - Workspaces response

@interface WorkspacesResponseSerializerDelegate ()
@property (nonatomic,strong) RepositoriesParserDelegate *parserDelegate;
@end

@implementation WorkspacesResponseSerializerDelegate

-(instancetype)init {
    self = [super init];
    if (self) {
        self.parserDelegate = [[RepositoriesParserDelegate alloc] init];
    }
    
    return self;
}

-(id <NSXMLParserDelegate>)xmlParserDelegate {
    return self.parserDelegate;
}

-(id)parseResult {
    NSArray *result = nil;
    if (self.parserDelegate.repositories) {
        result = [NSArray arrayWithArray:self.parserDelegate.repositories];
    }
    
    return result;
}

-(NSDictionary*)errorUserInfo:(id)response {
    return @{
             NSLocalizedDescriptionKey : NSLocalizedStringFromTable(@"Error when parsing get repositories response", nil, @"PydioSDK"),
             NSLocalizedFailureReasonErrorKey : [NSString stringWithFormat:NSLocalizedStringFromTable(@"Could not extract get repositories result: %@", nil, @"PydioSDK"), response]
             };
}

@end

#pragma mark - List Files Response

@interface ListFilesResponseSerializerDelegate ()
@property (nonatomic,strong) ListFilesResponseParserDelegate* parserDelegate;
@end

@implementation ListFilesResponseSerializerDelegate

-(instancetype)init {
    self = [super init];
    if (self) {
        self.parserDelegate = [[ListFilesResponseParserDelegate alloc] init];
    }
    
    return self;
}

-(id <NSXMLParserDelegate>)xmlParserDelegate {
    return self.parserDelegate;
}

-(id)parseResult {
    NSArray *result = nil;
    if (self.parserDelegate.files) {
        result = [NSArray arrayWithArray:self.parserDelegate.files];
    }
    
    return result;
}

-(NSDictionary*)errorUserInfo:(id)response {
    return @{
             NSLocalizedDescriptionKey : NSLocalizedStringFromTable(@"Error when parsing list files response", nil, @"PydioSDK"),
             NSLocalizedFailureReasonErrorKey : [NSString stringWithFormat:NSLocalizedStringFromTable(@"Could not extract list files result: %@", nil, @"PydioSDK"), response]
             };
}

@end

#pragma mark - Mkdir Response

@interface SuccessResponseSerializerDelegate ()
@property (nonatomic, strong) SuccessResponseParserDelegate* parserDelegate;
@property (nonatomic, strong) NSString *actionName;
@end

@implementation SuccessResponseSerializerDelegate

-(instancetype)initWithAction:(NSString*)name {
    self = [super init];
    if (self) {
        self.parserDelegate = [[SuccessResponseParserDelegate alloc] init];
        self.actionName = name;
    }
    
    return self;
}

-(id <NSXMLParserDelegate>)xmlParserDelegate {
    return self.parserDelegate;
}

-(id)parseResult {
    PydioSuccessResponse *result = nil;
    if (self.parserDelegate.success) {
        result = [[PydioSuccessResponse alloc] init];
    }
    
    return result;
}

-(NSDictionary*)errorUserInfo:(id)response {
    return @{
             NSLocalizedDescriptionKey : [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error when parsing %@ response", nil, @"PydioSDK"), self.actionName],
             NSLocalizedFailureReasonErrorKey : [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@ result not recognizd as success: %@", nil, @"PydioSDK"), self.actionName, response]
            };
}

@end

