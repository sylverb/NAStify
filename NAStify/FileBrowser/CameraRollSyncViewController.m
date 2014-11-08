//
//  CameraRollSyncViewController.m
//  NAStify
//
//  Created by Sylver Bruneau on 08/08/2014.
//  Copyright (c) 2014 CodeIsALie. All rights reserved.
//

#import "CameraRollSyncViewController.h"
#import "ALAssetsGroupAdditions.h"

#define TAG_HUD_UPLOAD 0
#define TAG_SWITCH_PHOTOS 1
#define TAG_SWITCH_VIDEOS 2
#define TAG_SWITCH_MODE 3

#define SECTION_INDEX_MODE 0
#define SECTION_INDEX_TYPE_SELECTION 1
#define SECTION_INDEX_SELECTION 2
#define SECTION_INDEX_INFO 3

@interface CameraRollSyncViewController ()

@end

@implementation CameraRollSyncViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleHeight |
    UIViewAutoresizingFlexibleBottomMargin;
    
    [self.view addSubview:self.tableView];
    
	UIBarButtonItem *flexibleSpaceButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                             target:nil
                                                                                             action:nil];
    
    self.uploadButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Synchronize",nil)
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(uploadButton:event:)];
    
	UIBarButtonItem *cancelButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                      target:self
                                                                                      action:@selector(cancelButton:event:)];
    
    NSMutableArray *buttons = [NSMutableArray arrayWithCapacity:3];
    
    [buttons addObject:flexibleSpaceButtonItem];
    [buttons addObject:self.uploadButtonItem];
	[buttons addObject:flexibleSpaceButtonItem];
	[buttons addObject:cancelButtonItem];
	[buttons addObject:flexibleSpaceButtonItem];
	[self setToolbarItems:buttons];
    
    self.navigationItem.title = NSLocalizedString(@"Synchronize camera roll", nil);
    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
    [self.navigationController.toolbar setTintColor:[UIColor blackColor]];

    // Init default values
    self.library = [[ALAssetsLibrary alloc] init];
    self.selectedGroupsDict = [NSMutableDictionary dictionary];
    self.mode = CameraRollSyncModeAlbum;
    self.parsePhotos = YES;
    self.parseVideos = YES;
    
    self.parsingOnProgress = NO;
    self.uploadOnProgress = NO;
    self.allAlbumsSelected = YES;
    
    self.connectionManager.delegate = self;
    
    self.parsingOnProgress = YES;
    
    /* Get file list */
    [self.connectionManager listForPath:self.currentFolder];
    
	[self.navigationController setToolbarHidden:NO animated:NO];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    NSInteger rows = 0;
    switch (section)
    {
        case SECTION_INDEX_MODE:
        {
            rows = 1;
            break;
        }
        case SECTION_INDEX_TYPE_SELECTION:
        {
            rows = 2;
            break;
        }
        case SECTION_INDEX_SELECTION:
        {
            if (self.mode == CameraRollSyncModeAlbum)
            {
                if (self.allAlbumsSelected)
                {
                    rows = 1;
                }
                else
                {
                    rows = [self.groupsArray count] + 1;
                }
            }
            else
            {
                rows = 1;
            }
            break;
        }
        case SECTION_INDEX_INFO:
        {
            rows = 1;
        }
        default:
        {
            break;
        }
    }
    return rows;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	NSString * title = nil;
	switch (section)
    {
		case SECTION_INDEX_MODE:
        {
			title = NSLocalizedString(@"Selection mode",nil);
			break;
        }
		case SECTION_INDEX_TYPE_SELECTION:
        {
            if (self.mode == CameraRollSyncModeAlbum)
            {
                title = NSLocalizedString(@"Media type to synchronize",nil);
            }
            else if (self.mode == CameraRollSyncModePicker)
            {
                title = NSLocalizedString(@"Media type to show in picker",nil);
            }
			break;
        }
		case SECTION_INDEX_SELECTION:
        {
            if (self.mode == CameraRollSyncModeAlbum)
            {
                title = NSLocalizedString(@"Albums to synchronize",nil);
            }
            else
            {
                title = NSLocalizedString(@"Media selection",nil);
            }
			break;
        }
        case SECTION_INDEX_INFO:
        {
            if (self.mode == CameraRollSyncModeAlbum)
            {
                title = NSLocalizedString(@"Synchronization information",nil);
            }
            else
            {
                title = NSLocalizedString(@"Media files to upload",nil);
            }
        }
	}
	return title;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * CellIdentifier = @"Cell";
    static NSString * SwitchCellIdentifier = @"SwitchCell";
    static NSString * SegmentedIdentifier = @"SegmentedCell";
    static NSString * PhotoCellIdentifier = @"PhotoCell";
    
    UITableViewCell *cell = nil;
    
    switch (indexPath.section)
    {
        case SECTION_INDEX_MODE:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:SegmentedIdentifier];
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SegmentedIdentifier];
                    }
                    
                    // UISwitch setup
                    NSArray *cellSubViews = [[cell.textLabel superview] subviews];
                    for (id item in cellSubViews)
                    {
                        if ([item isKindOfClass:[UISegmentedControl class]])
                        {
                            UISegmentedControl *oldSegmentedControl = (UISegmentedControl *)item;
                            [oldSegmentedControl removeFromSuperview];
                            break;
                        }
                    }
                    
                    UISegmentedControl *segmentedCtrl = [[UISegmentedControl alloc] initWithItems:@[@"Album",@"Picker"]];
                    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
                    {
                        segmentedCtrl.frame = CGRectMake(90,5,180,35);
                    }
                    else
                    {
                        segmentedCtrl.frame = CGRectMake(10,5,300,35);
                    }

                    if (self.mode == CameraRollSyncModeAlbum)
                    {
                        segmentedCtrl.selectedSegmentIndex = 0;
                    }
                    else
                    {
                        segmentedCtrl.selectedSegmentIndex = 1;
                    }
                    segmentedCtrl.userInteractionEnabled = YES;
                    segmentedCtrl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                    segmentedCtrl.tag = TAG_SWITCH_MODE;
                    
                    [segmentedCtrl addTarget:self
                                      action:@selector(segmentedValueChanged:)
                            forControlEvents:UIControlEventValueChanged];

                    [[cell.textLabel superview] addSubview:segmentedCtrl];
                    break;
                }
            }
            break;
        }
        case SECTION_INDEX_TYPE_SELECTION:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (cell == nil)
                    {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SwitchCellIdentifier];
                    }
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    
                    cell.textLabel.text = NSLocalizedString(@"Photos",nil);
                    
                    // UISwitch setup
                    NSArray *cellSubViews = [[cell.textLabel superview] subviews];
                    for (id item in cellSubViews)
                    {
                        if ([item isKindOfClass:[UISwitch class]])
                        {
                            UISwitch *oldSwitch = (UISwitch *)item;
                            [oldSwitch removeFromSuperview];
                            break;
                        }
                    }
                    
                    UISwitch *aswitch = [[UISwitch alloc] initWithFrame:CGRectMake(cell.contentView.frame.size.width - 70,
                                                                                   7,
                                                                                   100,
                                                                                   30)];

                    aswitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                    
                    [aswitch setOn:self.parsePhotos animated:NO];
                    
                    [aswitch addTarget:self
                                action:@selector(switchValueChanged:)
                      forControlEvents:UIControlEventValueChanged];
                    aswitch.tag = TAG_SWITCH_PHOTOS;
                    [[cell.textLabel superview] addSubview:aswitch];
                    break;
                }
                case 1:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SwitchCellIdentifier];
                    }
                    
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    
                    cell.textLabel.text = NSLocalizedString(@"Videos",nil);
                    
                    // UISwitch setup
                    NSArray *cellSubViews = [[cell.textLabel superview] subviews];
                    for (id item in cellSubViews)
                    {
                        if ([item isKindOfClass:[UISwitch class]])
                        {
                            UISwitch *oldSwitch = (UISwitch *)item;
                            [oldSwitch removeFromSuperview];
                            break;
                        }
                    }
                    
                    UISwitch *aswitch = [[UISwitch alloc] initWithFrame:CGRectMake(cell.contentView.frame.size.width - 70,
                                                                                   7,
                                                                                   100,
                                                                                   30)];

                    aswitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                    
                    [aswitch setOn:self.parseVideos animated:NO];
                    
                    [aswitch addTarget:self
                                action:@selector(switchValueChanged:)
                      forControlEvents:UIControlEventValueChanged];
                    aswitch.tag = TAG_SWITCH_VIDEOS;
                    [[cell.textLabel superview] addSubview:aswitch];
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case SECTION_INDEX_SELECTION:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    if (self.mode == CameraRollSyncModeAlbum)
                    {
                        cell = [tableView dequeueReusableCellWithIdentifier:SwitchCellIdentifier];
                        if (cell == nil) {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SwitchCellIdentifier];
                        }
                        
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        
                        cell.textLabel.text = NSLocalizedString(@"All albums",nil);
                        
                        // UISwitch setup
                        NSArray *cellSubViews = [[cell.textLabel superview] subviews];
                        for (id item in cellSubViews)
                        {
                            if ([item isKindOfClass:[UISwitch class]])
                            {
                                UISwitch *oldSwitch = (UISwitch *)item;
                                [oldSwitch removeFromSuperview];
                                break;
                            }
                        }
                        
                        UISwitch *aswitch = [[UISwitch alloc] initWithFrame:CGRectMake(cell.contentView.frame.size.width - 70,
                                                                                       7,
                                                                                       100,
                                                                                       30)];
                        
                        aswitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                        
                        [aswitch setOn:self.allAlbumsSelected animated:NO];
                        
                        [aswitch addTarget:self
                                    action:@selector(switchAllAlbumValueChanged:)
                          forControlEvents:UIControlEventValueChanged];
                        aswitch.tag = 0;
                        [[cell.textLabel superview] addSubview:aswitch];
                    }
                    else
                    {
                        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                        if (cell == nil)
                        {
                            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
                        }
                        
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.textLabel.text = NSLocalizedString(@"Select media to upload",nil);
                        cell.textLabel.textAlignment = NSTextAlignmentCenter;
                    }
                    break;
                }
                default:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:PhotoCellIdentifier];
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PhotoCellIdentifier];
                    }
                    
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.font = [UIFont systemFontOfSize:13];
                    
                    // Get count
                    ALAssetsGroup *g = (ALAssetsGroup*)self.groupsArray[indexPath.row - 1];
                    
                    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%ld)",[g valueForProperty:ALAssetsGroupPropertyName],(long)[g numberOfPhotoAssets:self.parsePhotos andVideoAssets:self.parseVideos]];
                    [cell.imageView setImage:[UIImage imageWithCGImage:[(ALAssetsGroup*)self.groupsArray[indexPath.row - 1] posterImage]]];
                    
                    // UISwitch setup
                    NSArray *cellSubViews = [[cell.textLabel superview] subviews];
                    for (id item in cellSubViews) {
                        if ([item isKindOfClass:[UISwitch class]]) {
                            UISwitch *oldSwitch = (UISwitch *)item;
                            [oldSwitch removeFromSuperview];
                            break;
                        }
                    }
                    
                    UISwitch *aswitch = [[UISwitch alloc] initWithFrame:CGRectMake(cell.contentView.frame.size.width - 70,
                                                                                   7,
                                                                                   100,
                                                                                   30)];
                    aswitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                    
                    
                    [aswitch setOn:[[self.selectedGroupsDict objectForKey:[g valueForProperty:ALAssetsGroupPropertyPersistentID]] boolValue]
                          animated:NO];
                    
                    [aswitch addTarget:self
                                action:@selector(switchAlbumValueChanged:)
                      forControlEvents:UIControlEventValueChanged];
                    
                    aswitch.tag = indexPath.row - 1;
                    [[cell.textLabel superview] addSubview:aswitch];
                    break;
                }
            }
            break;
        }
        case SECTION_INDEX_INFO:
        {
            switch (indexPath.row)
            {
                case 0:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
                    if (cell == nil) {
                        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
                    }
                    
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    cell.textLabel.textAlignment = NSTextAlignmentCenter;

                    if (self.parsingOnProgress)
                    {
                        cell.textLabel.text = NSLocalizedString(@"Elements to synchronize : parsing",nil);
                    }
                    else
                    {
                        if (self.mode == CameraRollSyncModeAlbum)
                        {
                            cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Elements to synchronize : %d",nil),[self.assetItems count]];
                        }
                        else
                        {
                            cell.textLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Elements to upload : %d",nil),[self.assetItems count]];
                        }
                    }
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Show image picker
    if ((indexPath.section == SECTION_INDEX_SELECTION) && (indexPath.row == 0) && (self.mode == CameraRollSyncModePicker))
    {
        ELCImagePickerController *elcPicker = [[ELCImagePickerController alloc] initImagePicker];
        
        elcPicker.maximumImagesCount = 100;
        elcPicker.returnsImage = NO;
        elcPicker.onOrder = YES;
        
        NSMutableArray *mediaTypes = [NSMutableArray array];
        if (self.parsePhotos)
        {
            [mediaTypes addObject:(NSString *)kUTTypeImage];
        }
        if (self.parseVideos)
        {
            [mediaTypes addObject:(NSString *)kUTTypeMovie];
        }

        elcPicker.mediaTypes = mediaTypes;
         
        elcPicker.imagePickerDelegate = self;
        
        [self presentViewController:elcPicker animated:YES completion:nil];
    }
}

#pragma mark - CMDelegate

- (void)CMFilesList:(NSDictionary *)dict
{
    if ([[dict objectForKey:@"success"] boolValue])
    {
        NSArray *filesList = [dict objectForKey:@"filesList"];
        
        self.filesArray = [[NSMutableArray alloc] init];
        
        for (NSDictionary *element in filesList)
        {
            FileItem *fileItem = [[FileItem alloc] init];
            fileItem.name = [element objectForKey:@"filename"];
            fileItem.isDir = [[element objectForKey:@"isdir"] boolValue];
            fileItem.shortPath = self.currentFolder.path;
            if ([self.currentFolder.path isEqualToString:@"/"])
            {
                fileItem.path = [NSString stringWithFormat:@"/%@",fileItem.name]; // Path to file
            }
            else
            {
                fileItem.path = [NSString stringWithFormat:@"%@/%@",self.currentFolder.path,fileItem.name]; // Path to file
            }
            if ([element objectForKey:@"path"])
            {
                fileItem.fullPath = [element objectForKey:@"path"]; // Path with filename/foldername
            }
            else
            {
                fileItem.fullPath = fileItem.path;
            }
            
            if ([element objectForKey:@"id"])
            {
                fileItem.objectIds = [self.currentFolder.objectIds arrayByAddingObject:[element objectForKey:@"id"]];
            }
            
            fileItem.isCompressed = NO;
            
            if (fileItem.isDir)
            {
                fileItem.fileSize = nil;
                fileItem.fileSizeNumber = nil;
                fileItem.owner = nil;
                fileItem.isEjectable = NO;
            }
            else
            {
                if ([element objectForKey:@"type"])
                {
                    fileItem.type = [element objectForKey:@"type"];
                }
                else
                {
                    fileItem.type = [[fileItem.name componentsSeparatedByString:@"."] lastObject];
                }
                
                if ([element objectForKey:@"filesizenumber"])
                {
                    fileItem.fileSizeNumber = [element objectForKey:@"filesizenumber"];
                }
                else
                {
                    fileItem.fileSizeNumber = nil;
                }
                fileItem.fileSize = [[element objectForKey:@"filesizenumber"] stringForNumberOfBytes];
                
                fileItem.isEjectable = NO;
            }
            fileItem.writeAccess = [[element objectForKey:@"writeaccess"] boolValue];
            
            /* Date */
            if (([element objectForKey:@"date"]) &&
                ([[element objectForKey:@"date"] doubleValue] != 0))
            {
                fileItem.fileDateNumber = [NSNumber numberWithDouble:[[element objectForKey:@"date"] doubleValue]];
                NSTimeInterval mtime = (NSTimeInterval)[[element objectForKey:@"date"] doubleValue];
                NSDate *mdate = [NSDate dateWithTimeIntervalSince1970:mtime];
                NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
                [formatter setDateStyle:NSDateFormatterMediumStyle];
                [formatter setTimeStyle:NSDateFormatterShortStyle];
                
                fileItem.fileDate = [formatter stringFromDate:mdate];
            }
            [self.filesArray addObject:fileItem];
        }
        
        [self parseCameraRoll];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Synchronize error",nil)
                                                        message:NSLocalizedString([dict objectForKey:@"error"],nil)
                                                       delegate:nil
                                              cancelButtonTitle:nil
                                              otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
        [alert show];
    }
}

- (void)CMUploadProgress:(NSDictionary *)dict
{
    if ([dict objectForKey:@"progress"])
    {
        float progress = [[dict objectForKey:@"progress"] floatValue];
        if (progress != 0)
        {
            self.hud.mode = MBProgressHUDModeAnnularDeterminate;
            self.hud.progress = progress;
        }
        if ([dict objectForKey:@"uploadedBytes"])
        {
            NSNumber *uploaded = [dict objectForKey:@"uploadedBytes"];
            NSNumber *totalSize = [dict objectForKey:@"totalBytes"];
            self.hud.detailsLabelText = [NSString stringWithFormat:@"%@ of %@ done",[uploaded stringForNumberOfBytes],[totalSize stringForNumberOfBytes]];
        }
    }
    else
    {
        NSNumber *uploaded = [dict objectForKey:@"uploadedBytes"];
        self.hud.detailsLabelText = [NSString stringWithFormat:@"%@ done",[uploaded stringForNumberOfBytes]];
    }
}

- (void)CMUploadFinished:(NSDictionary *)dict
{
    if ([[dict objectForKey:@"success"] boolValue])
    {
        if ([self.assetItems count] > 1)
        {
            // delete previous temp file
            [self deleteFileFromAsset:[self.assetItems objectAtIndex:0]];
            
            [self.assetItems removeObjectAtIndex:0];
            
            self.filesCount++;
            [self performSelector:@selector(uploadNextFile)
                       withObject:nil];
        }
        else if ([self.assetItems count] == 1)
        {
            // delete previous temp file
            [self deleteFileFromAsset:[self.assetItems objectAtIndex:0]];
            
            [self.assetItems removeObjectAtIndex:0];

            self.uploadOnProgress = NO;
            
            // Synchronization done, quit menu
            [self.hud hide:YES];
            self.hud = nil;
            
            if(self.delegate && [self.delegate respondsToSelector:@selector(backFromModalView:)])
            {
                [self.delegate backFromModalView:YES];
            }
            [self.navigationController dismissViewControllerAnimated:YES
                                                          completion:nil];
        }
        else
        {
            // Shall not happen
            self.uploadOnProgress = NO;

            [self.hud hide:YES];
            self.hud = nil;
        }
	}
    else
    {
        self.uploadOnProgress = NO;
        [self.hud hide:YES];
        
        NSString *message;
        if (self.mode == CameraRollSyncModeAlbum)
        {
            message = NSLocalizedString(@"Camera roll sync failed : ",nil);
        }
        else
        {
            message = NSLocalizedString(@"Media upload failed : ",nil);
        }
        message = [message stringByAppendingString:[dict objectForKey:@"error"]];
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Camera roll sync failed",nil)
														message:message
													   delegate:nil
											  cancelButtonTitle:nil
											  otherButtonTitles:NSLocalizedString(@"OK",nil),nil];
		[alert show];
	}
}

#pragma mark - UISwitch management

- (void)switchAllAlbumValueChanged:(id)sender
{
    self.allAlbumsSelected = [sender isOn];
    self.parsingOnProgress = YES;
    [self.tableView reloadData];
    [self parseCameraRoll];
}

- (void)switchAlbumValueChanged:(id)sender
{
	NSInteger tag = ((UISwitch *)sender).tag;
    ALAssetsGroup *group = (ALAssetsGroup*)self.groupsArray[tag];
    
    if ([sender isOn])
    {
        [self.selectedGroupsDict addEntriesFromDictionary:
         [NSDictionary dictionaryWithObject:@(TRUE)
                                     forKey:[group valueForProperty:ALAssetsGroupPropertyPersistentID]]];
    }
    else
    {
        [self.selectedGroupsDict removeObjectForKey:[group valueForProperty:ALAssetsGroupPropertyPersistentID]];
    }
    self.parsingOnProgress = YES;
    [self.tableView reloadData];
    [self parseCameraRoll];
}

- (void)switchValueChanged:(id)sender
{
	NSInteger tag = ((UISwitch *)sender).tag;
    switch (tag)
    {
        case TAG_SWITCH_PHOTOS:
        {
            self.parsePhotos = [sender isOn];
            self.parsingOnProgress = YES;
            [self.tableView reloadData];
            [self parseCameraRoll];
            break;
        }
        case TAG_SWITCH_VIDEOS:
        {
            self.parseVideos = [sender isOn];
            self.parsingOnProgress = YES;
            [self.tableView reloadData];
            [self parseCameraRoll];
            break;
        }
    }
}

#pragma mark - UISegmentedControl management

- (void)segmentedValueChanged:(id)sender {
	NSInteger tag = ((UISegmentedControl *)sender).tag;
	switch (tag)
    {
		case TAG_SWITCH_MODE:
        {
            switch ([sender selectedSegmentIndex])
            {
                case CameraRollSyncModeAlbum:
                {
                    self.mode = CameraRollSyncModeAlbum;
                    self.uploadButtonItem.title = NSLocalizedString(@"Synchronize", nil);
                    [self parseCameraRoll];
                    break;
                }
                case CameraRollSyncModePicker:
                {
                    self.mode = CameraRollSyncModePicker;
                    self.uploadButtonItem.title = NSLocalizedString(@"Upload", nil);
                    self.assetItems = nil;
                    break;
                }
                default:
                    break;
            }
            break;
        }
	}
    [self.tableView reloadData];
}

#pragma mark - MBProgressHUDDelegate

- (void)hudDidCancel:(MBProgressHUD *)hud;
{
    switch (hud.tag)
    {
        case TAG_HUD_UPLOAD:
        {
            [self.connectionManager cancelUploadTask];
            [hud hide:YES];
            
            // delete previous temp file
            [self deleteFileFromAsset:[self.assetItems objectAtIndex:0]];
            
            [self.assetItems removeAllObjects];
            
            self.uploadOnProgress = NO;
            self.parsingOnProgress = YES;
            [self.tableView reloadData];
            
            /* Refresh file list */
            [self.connectionManager listForPath:self.currentFolder];

            break;
        }
        default:
            break;
    }
}

#pragma mark - Tabbar buttons Methods

- (void)uploadButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    if (([self.assetItems count] > 0) &&
        (self.parsingOnProgress == NO) &&
        (self.uploadOnProgress == NO))
    {
        self.uploadOnProgress = YES;
        self.filesTotal = [self.assetItems count];
        self.filesCount = 1;

        self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];

        if (ServerSupportsFeature(UploadCancel))
        {
            self.hud.allowsCancelation = YES;
            self.hud.tag = TAG_HUD_UPLOAD;
        }
        self.hud.delegate = self;
        NSString *text;
        if (self.mode == CameraRollSyncModeAlbum)
        {
            text = [NSLocalizedString(@"Synchronizing", nil) stringByAppendingFormat:@" (%ld/%ld)",(long)self.filesCount,(long)self.filesTotal];
        }
        else
        {
            text = [NSLocalizedString(@"Uploading", nil) stringByAppendingFormat:@" (%ld/%ld)",(long)self.filesCount,(long)self.filesTotal];
        }
        self.hud.labelText = text;
        [self.hud show:YES];
        
        [self performSelector:@selector(uploadNextFile)
                   withObject:nil
                   afterDelay:0.1];
    }
    else if (([self.assetItems count] == 0) ||
             (self.parsingOnProgress == YES))
    {
        NSString *message;
        if (self.parsingOnProgress)
        {
            message = NSLocalizedString(@"Parsing on progress",nil);
        }
        else
        {
            message = NSLocalizedString(@"No new media to synchronize",nil);
        }
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Synchronization"
                                                         message:NSLocalizedString(@"No new media to synchronize",nil)
                                                        delegate:nil
                                               cancelButtonTitle:@"Ok"
                                               otherButtonTitles:nil];
        [alert show];
    }
}

- (void)cancelButton:(UIBarButtonItem*)sender event:(UIEvent*)event
{
    if (self.uploadOnProgress == NO)
    {
        if(self.delegate && [self.delegate respondsToSelector:@selector(backFromModalView:)])
        {
            [self.delegate backFromModalView:YES];
        }
        [self.navigationController dismissViewControllerAnimated:YES
                                                      completion:nil];
    }
}

#pragma mark - Media file uploading

- (void)uploadNextFile
{
    if ([self.assetItems count] > 0)
    {
        self.hud.mode = MBProgressHUDModeIndeterminate;
        self.hud.progress = 0.0f;
        self.hud.labelText = [NSLocalizedString(@"Synchronizing", nil) stringByAppendingFormat:@" (%ld/%ld)",(long)self.filesCount,(long)self.filesTotal];
        self.hud.detailsLabelText = nil;
        
        ALAsset *asset = [self.assetItems objectAtIndex:0];
        ALAssetRepresentation *rep = [asset defaultRepresentation];
        NSString *file = [self createFileFromAsset:asset];
        FileItem *fileItem = [[FileItem alloc] init];
        fileItem.path = file;
        fileItem.shortPath = [file stringByDeletingLastPathComponent];
        fileItem.fullPath = file;
        fileItem.name = [file lastPathComponent];
        fileItem.fileSizeNumber = [NSNumber numberWithLongLong:[rep size]];
        fileItem.fileDateNumber = [NSNumber numberWithDouble:[[asset valueForProperty:ALAssetPropertyDate] timeIntervalSince1970]];

        [self.connectionManager uploadLocalFile:fileItem
                                         toPath:self.currentFolder
                                      overwrite:YES
                                    serverFiles:self.filesArray];
    }
}

#pragma mark - Camera Roll parsing

- (void)parseCameraRoll
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        @autoreleasepool {
            if (self.groupsArray == nil)
            {
                self.groupsArray = [NSMutableArray array];
            }
            __block NSInteger parsedArrayCount = 0;
            
            NSMutableDictionary *assetsDict = [NSMutableDictionary dictionary];
            
            // Asset enumerator Block
            void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *result, NSUInteger index, BOOL *stop)
            {
                if(result != nil)
                {
                    NSString *type = [result valueForProperty:@"ALAssetPropertyType"];
                    if (((type == ALAssetTypePhoto) && (self.parsePhotos)) ||
                        ((type == ALAssetTypeVideo) && (self.parseVideos)))
                    {
                        ALAssetRepresentation *rep = [result defaultRepresentation];
                        if (rep != nil)
                        {
                            NSString *fileName = [rep filename];
                            
                            if (!assetsDict[fileName])
                            {
                                [assetsDict addEntriesFromDictionary:[NSDictionary dictionaryWithObject:result forKey:fileName]];
                            }
                        }
                    }
                    return;
                }
                else
                {
                    parsedArrayCount ++;
                    // If last group parsed, update info
                    if (parsedArrayCount == [self.selectedGroupsDict count])
                    {
                        for (FileItem *file in self.filesArray)
                        {
                            [assetsDict removeObjectForKey:file.name];
                        }
                        self.assetItems = [NSMutableArray arrayWithArray:[assetsDict allValues]];
                        self.parsingOnProgress = NO;
                        
                        [self.tableView reloadData];
                    }
                }
            };
            
            // Group enumerator Block
            void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) = ^(ALAssetsGroup *group, BOOL *stop)
            {
                if (group != nil)
                {
                    if (self.allAlbumsSelected)
                    {
                        // Select all groups if needed
                        [self.selectedGroupsDict addEntriesFromDictionary:
                         [NSDictionary dictionaryWithObject:@(TRUE)
                                                     forKey:[group valueForProperty:ALAssetsGroupPropertyPersistentID]]];
                    }

                    BOOL assetToAdd = YES;
                    for (ALAssetsGroup *assetGroups in self.groupsArray)
                    {
                        if ([[assetGroups valueForProperty:ALAssetsGroupPropertyPersistentID] isEqualToString:[group valueForProperty:ALAssetsGroupPropertyPersistentID]])
                        {
                            assetToAdd = NO;
                            break;
                        }
                    }

                    if (assetToAdd)
                    {
                        [self.groupsArray addObject:group];
                    }
                }
                else
                {
                    // Last group parsed, now parse ALAssets of each group
                    if ([self.selectedGroupsDict count] > 0)
                    {
                        for (ALAssetsGroup *assetGroups in self.groupsArray)
                        {
                            if ((self.allAlbumsSelected) ||
                                ([[self.selectedGroupsDict objectForKey:[assetGroups valueForProperty:ALAssetsGroupPropertyPersistentID]] boolValue]))
                            {
                                [assetGroups enumerateAssetsUsingBlock:assetEnumerator];
                            }
                        }
                    }
                    else
                    {
                        // No element selected, return 0 items
                        self.assetItems = nil;
                        self.parsingOnProgress = NO;
                        
                        [self.tableView reloadData];
                    }
                }
            };
            
            // Group Enumerator Failure Block
            void (^assetGroupEnumberatorFailure)(NSError *) = ^(NSError *error) {
                
                UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                 message:[NSString stringWithFormat:@"Album Error: %@", [error description]]
                                                                delegate:nil
                                                       cancelButtonTitle:@"Ok"
                                                       otherButtonTitles:nil];
                [alert show];
            };
            
            // Enumerate Albums
            [self.library enumerateGroupsWithTypes:ALAssetsGroupAll
                                        usingBlock:assetGroupEnumerator
                                      failureBlock:assetGroupEnumberatorFailure];
            
        }
    });
}

#pragma mark ELCImagePickerControllerDelegate Methods

- (void)elcImagePickerController:(ELCImagePickerController *)picker didFinishPickingMediaWithInfo:(NSArray *)info
{
    [self dismissViewControllerAnimated:YES completion:nil];
	
    self.assetItems = [NSMutableArray array];
    
    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *asset)
    {
        [self.assetItems addObject:asset];
        if ([[asset valueForProperty:ALAssetPropertyAssetURL] isEqual:[[info lastObject] objectForKey:UIImagePickerControllerReferenceURL]])
        {
            // Last element parsed, update info
            [self.tableView reloadData];
        }
    };

    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *error)
    {
        NSLog(@"Can't get asset - %@",[error localizedDescription]);
    };

	for (NSDictionary *dict in info)
    {
        NSLog(@"dict %@",dict);
        [self.library assetForURL:[dict objectForKey:UIImagePickerControllerReferenceURL]
                       resultBlock:resultblock
                      failureBlock:failureblock];
    }
}

- (void)elcImagePickerControllerDidCancel:(ELCImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - File management

- (NSString *)createFileFromAsset:(ALAsset *)asset
{
    ALAssetRepresentation *rep = [asset defaultRepresentation];
    
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[rep filename]];
    
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if (!handle)
    {
        //FIXME: Handle error
    }
    
    // Create a buffer for the asset
    static const NSUInteger BufferSize = 1024*1024;
    uint8_t *buffer = calloc(BufferSize, sizeof(*buffer));
    NSUInteger offset = 0, bytesRead = 0;
    
    // Read the buffer and write the data to your destination path as you go
    do
    {
        @try
        {
            bytesRead = [rep getBytes:buffer
                           fromOffset:offset
                               length:BufferSize
                                error:NULL];
            [handle writeData:[NSData dataWithBytesNoCopy:buffer length:bytesRead freeWhenDone:NO]];
            offset += bytesRead;
        }
        @catch (NSException *exception)
        {
            //FIXME: Handle exception
            free(buffer);
        }
    } while (bytesRead > 0);
    
    free(buffer);
    
    // Set creating date info according to EXIF info
    NSDictionary* attr = [NSDictionary dictionaryWithObjectsAndKeys:
                          [asset valueForProperty:ALAssetPropertyDate], NSFileModificationDate,
                          nil];
    [[NSFileManager defaultManager] setAttributes:attr
                                     ofItemAtPath:filePath
                                            error:NULL];
    
    return filePath;
}

- (void)deleteFileFromAsset:(ALAsset *)asset
{
    ALAssetRepresentation *rep = [asset defaultRepresentation];
    
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[rep filename]];
    
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];
}

@end
