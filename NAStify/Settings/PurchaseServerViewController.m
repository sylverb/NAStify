//
//  PurchaseServerViewController.m
//  NAStify
//
//  Created by Sylver Bruneau.
//  Copyright (c) 2015 CodeIsALie. All rights reserved.
//

#import "PurchaseServerViewController.h"
#import "SBNetworkActivityIndicator.h"
// In APP Purchase
#import <StoreKit/StoreKit.h>
#import "MKStoreKit.h"
#import "SKProduct+priceAsString.h"
#import "MAConfirmButton.h"

@interface PurchaseServerViewController ()

@end

@implementation PurchaseServerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // In-App purchase management
    [[NSNotificationCenter defaultCenter] addObserverForName:kMKStoreKitProductsAvailableNotification
                                                      object:nil
                                                       queue:[[NSOperationQueue alloc] init]
                                                  usingBlock:^(NSNotification *note) {
                                                      // End the network activity spinner
                                                      [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                                                      
                                                      for (SKProduct *product in [[MKStoreKit sharedKit] availableProducts])
                                                      {
                                                          NSLog(@"Title: %@\nDescription: %@\nPrice: %@\n",product.localizedTitle,product.localizedDescription,[product priceAsString]);
                                                          dispatch_async(dispatch_get_main_queue(), ^{
                                                              [self.tableView reloadData];
                                                          });
                                                      }
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kMKStoreKitProductPurchasedNotification
                                                      object:nil
                                                       queue:[[NSOperationQueue alloc] init]
                                                  usingBlock:^(NSNotification *note) {
                                                      // End the network activity spinner
                                                      [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                                                      
                                                      NSLog(@"Purchased/Subscribed to product with id: %@", [note object]);
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          [self.tableView reloadData];
                                                      });
                                                  }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:kMKStoreKitProductPurchaseFailedNotification
                                                      object:nil
                                                       queue:[[NSOperationQueue alloc] init]
                                                  usingBlock:^(NSNotification *note) {
                                                      // End the network activity spinner
                                                      [[SBNetworkActivityIndicator sharedInstance] endActivity:self];
                                                      
                                                      SKPaymentTransaction *transaction = (SKPaymentTransaction *)note.object;
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                                                      message:transaction.error.localizedDescription
                                                                                     delegate:nil
                                                                            cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                                            otherButtonTitles: nil] show];
                                                          
                                                          [self.tableView reloadData];
                                                      });
                                                  }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [MKStoreKit sharedKit].availableProducts.count - 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *PurchaseCellIdentifier = @"PurchaseCell";
    UITableViewCell *cell = nil;
    
    switch (indexPath.section)
    {
        case 0:
        {
            switch (indexPath.row)
            {
                default:
                {
                    SKProduct *product = [[MKStoreKit sharedKit].availableProducts objectAtIndex:indexPath.row + 1];
                    
                    cell = [tableView dequeueReusableCellWithIdentifier:PurchaseCellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                      reuseIdentifier:PurchaseCellIdentifier];
                        
                        MAConfirmButton *defaultButton = nil;
                        
                        if ([[MKStoreKit sharedKit] isProductPurchased:product.productIdentifier])
                        {
                            defaultButton = [MAConfirmButton buttonWithDisabledTitle:NSLocalizedString(@"Confirmed",nil)];
                        }
                        else
                        {
                            defaultButton = [MAConfirmButton buttonWithTitle:product.priceAsString
                                                                     confirm:NSLocalizedString(@"Buy now",nil)];
                        }
                        [defaultButton setAnchor:CGPointMake(270, 10)];
                        [defaultButton addTarget:self action:@selector(confirmAction:) forControlEvents:UIControlEventTouchUpInside];
                        defaultButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                        
                        defaultButton.tag = indexPath.row + 1;
                        [cell addSubview:defaultButton];
                    }
                    else
                    {
                        MAConfirmButton *defaultButton = nil;
                        NSArray *subviews = [cell subviews];
                        for (UIView *subview in subviews)
                        {
                            if ([subview isKindOfClass:[MAConfirmButton class]])
                            {
                                defaultButton = (MAConfirmButton *)subview;
                                break;
                            }
                            
                        }
                        if ([[MKStoreKit sharedKit] isProductPurchased:product.productIdentifier])
                        {
                            [defaultButton disableWithTitle:NSLocalizedString(@"Confirmed",nil)];
                            defaultButton = [MAConfirmButton buttonWithDisabledTitle:NSLocalizedString(@"Confirmed",nil)];
                        }
                        else
                        {
                            [defaultButton enableWithTitle:product.priceAsString
                                                   confirm:NSLocalizedString(@"Buy now",nil)];
                        }
                        defaultButton.tag = indexPath.row + 1;
                    }
                    
                    cell.textLabel.textColor = [UIColor blackColor];
                    if ([[MKStoreKit sharedKit] isProductPurchased:product.productIdentifier])
                    {
                        cell.accessoryType = UITableViewCellAccessoryNone;
                    }
                    else
                    {
                        cell.accessoryType = UITableViewCellAccessoryDetailButton;
                    }
                    cell.textLabel.text = product.localizedTitle;
                    
                    break;
                }
            }
            break;
        }
        default:
        {
            break;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section)
    {
        case 0:
        {
            switch (indexPath.row)
            {
                default:
                {
                    SKProduct *product = [[MKStoreKit sharedKit].availableProducts objectAtIndex:indexPath.row + 1];
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Info", nil)
                                                message:product.localizedDescription
                                               delegate:nil
                                      cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                      otherButtonTitles: nil] show];
                    break;
                }
            }
            break;
        }
    }
}

#pragma mark - MAConfirmButton action button

- (void)confirmAction:(id)sender
{
    MAConfirmButton *button = (MAConfirmButton *)sender;
    [button disableWithTitle:NSLocalizedString(@"Processing", nil)];
    
    SKProduct *product = [[MKStoreKit sharedKit].availableProducts objectAtIndex:button.tag];
    
    // Start the network activity spinner
    [[SBNetworkActivityIndicator sharedInstance] beginActivity:self];
    
    [[MKStoreKit sharedKit] initiatePaymentRequestForProductWithIdentifier:product.productIdentifier];
}

@end
