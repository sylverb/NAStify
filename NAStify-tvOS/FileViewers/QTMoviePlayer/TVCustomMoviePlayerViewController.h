//
//  CustomMoviePlayerViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CustomMoviePlayerViewController : UIViewController

@property (nonatomic,strong) NSURL *url;
@property (nonatomic,strong) NSString *filename;
@property (nonatomic) BOOL allowsAirPlay;

- (instancetype)initWithFilename:(NSString *)filename;
@end
