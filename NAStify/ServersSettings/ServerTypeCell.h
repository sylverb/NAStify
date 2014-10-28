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
{
    UIImageView *serverTypeImage;
}

@property (nonatomic) SERVER_TYPE serverType;

@end
