//
//  ServersListViewController.h
//  NAStify-tvOS
//
//  Created by Sylver B on 27/09/15.
//  Copyright © 2015 Sylver B. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ServerCell.h"
#import "AFNetworking.h"
#import "UPnPManager.h"

@interface ServersListViewController : UITableViewController <UPnPDBObserver> {
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

