//
//  ServersListViewController.h
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2012 CodeIsALie. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ServerCell.h"
#import "AFNetworking.h"
#import "UPnPManager.h"

@class ConnectionManager;

@interface ServersListViewController : UITableViewController<UITextFieldDelegate,UPnPDBObserver> {
    NSArray *_filteredUPNPDevices;
    NSArray *_UPNPdevices;
    
    BOOL _udnpDiscoveryRunning;
    NSTimer *_searchTimer;
}

@property(nonatomic, strong) NSMutableArray * accounts;
@property(nonatomic, strong) AFHTTPRequestOperationManager *manager;

// UPnPDBObserver
- (void)UPnPDBUpdated:(UPnPDB*)sender;
- (void)UPnPDBWillUpdate:(UPnPDB*)sender;

@end
