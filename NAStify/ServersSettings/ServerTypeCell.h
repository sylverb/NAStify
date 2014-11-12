//
//  ServerTypeCell.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UserAccount.h"

@interface ServerTypeCell : UITableViewCell

@property (nonatomic) SERVER_TYPE serverType;
@property (nonatomic, retain) UIImageView *serverTypeImage;

@end
