//
//  BoxAuthorizationNavigationController.m
//  BoxSDKSampleApp
//
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "BoxAuthorizationNavigationController.h"

@implementation BoxAuthorizationNavigationController

#pragma mark - BoxAuthorizationViewControllerDelegate methods

- (void)authorizationViewControllerDidStartLoading:(BoxAuthorizationViewController *)authorizationViewController
{
}

- (void)authorizationViewControllerDidFinishLoading:(BoxAuthorizationViewController *)authorizationViewController
{
}

- (void)authorizationViewControllerDidCancel:(BoxAuthorizationViewController *)authorizationViewController
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)authorizationViewController:(BoxAuthorizationViewController *)authorizationViewController shouldLoadReceivedOAuth2RedirectRequest:(NSURLRequest *)request
{
    [[BoxSDK sharedSDK].OAuth2Session performAuthorizationCodeGrantWithReceivedURL:request.URL];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    return NO;
}

@end
