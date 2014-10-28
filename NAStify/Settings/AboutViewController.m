//
//  AboutViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "AboutViewController.h"

@implementation AboutViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    self.webView.hidden = YES;
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.view addSubview:self.webView];
    
    self.navigationItem.title = NSLocalizedString(@"About", nil);
    
    self.view.backgroundColor = [UIColor colorWithWhite:.122 alpha:1.];
    self.webView.backgroundColor = [UIColor colorWithWhite:.122 alpha:1.];
    
    NSString *htmlContent = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"licenses" ofType:@"html"]
                                                      encoding:NSASCIIStringEncoding
                                                         error:nil];

    [self.webView loadHTMLString:[NSString stringWithString:htmlContent] baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]]];
    htmlContent = nil;
    self.webView.delegate = self;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *requestURL = request.URL;
    if (![requestURL.scheme isEqualToString:@""])
        return ![[UIApplication sharedApplication] openURL:requestURL];
    else
        return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    webView.alpha = 0.;
    CGFloat alpha = 1.;
    
    void (^animationBlock)() = ^() {
        webView.alpha = alpha;
    };
    
    void (^completionBlock)(BOOL finished) = ^(BOOL finished) {
        webView.hidden = NO;
    };
    
    [UIView animateWithDuration:.3 animations:animationBlock completion:completionBlock];
}

@end
