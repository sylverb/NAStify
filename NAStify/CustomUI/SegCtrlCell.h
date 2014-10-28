//
//  SegCtrlCell.h
//  Synology DS
//
//  Created by Sylver Bruneau on 14/10/10.
//  Copyright 2010 Sylver Bruneau. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SegCtrlCell : UITableViewCell {
	UILabel *label;
	UISegmentedControl *segmentedControl;
}

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;

- (id)initWithStyle:(UITableViewCellStyle)style
    reuseIdentifier:(NSString *)reuseIdentifier
          withItems:(NSArray *)items;
- (void)setCellDataWithLabelString:(NSString *)labelText 
						  withSelectedIndex:(NSInteger)idx
							andTag:(NSInteger)fieldTag;

@end
