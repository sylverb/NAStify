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
#import <arpa/inet.h>
#import <bdsm/bdsm.h>

@interface ServersListViewController : UITableViewController <UPnPDBObserver> {
    NSArray *_filteredUPNPDevices;
    NSArray *_UPNPdevices;
    
    BOOL _udnpDiscoveryRunning;
    BOOL _netbiosDiscoveryRunning;
    NSTimer *_searchTimer;
    
    netbios_ns *_ns;
}

@property(nonatomic, strong) NSMutableArray *accounts;
@property(nonatomic, strong) AFHTTPRequestOperationManager *manager;
@property(nonatomic, strong) NSMutableArray *smbDevices;

// UPnPDBObserver
- (void)UPnPDBUpdated:(UPnPDB*)sender;
- (void)UPnPDBWillUpdate:(UPnPDB*)sender;

@end

