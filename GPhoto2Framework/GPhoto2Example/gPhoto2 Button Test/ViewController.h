//
//  ViewController.h
//  gPhoto2 Button Test
//
//  Created by Hendrik Holtmann on 24.10.18.
//  Copyright © 2018 Hendrik Holtmann. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SSDP/SSDPServiceBrowser.h"

@interface ViewController : UIViewController <SSDPServiceBrowserDelegate, UITableViewDelegate, UITableViewDataSource>

- (IBAction)discoverCamera:(id)sender;
    @property (weak, nonatomic) IBOutlet UILabel *cameraLabel;
    @property (weak, nonatomic) IBOutlet UILabel *iPLabel;
    - (IBAction)checkFileSystem:(id)sender;
    @property (weak, nonatomic) IBOutlet UIButton *checkFileSystemButton;
    - (IBAction)shootAndSave:(id)sender;
    @property (weak, nonatomic) IBOutlet UIButton *shootSaveButton;
    - (IBAction)cameraProperties:(id)sender;
    @property (weak, nonatomic) IBOutlet UIButton *cameraPropertiesButton;
    - (IBAction)setCaptureTarget:(id)sender;
    @property (weak, nonatomic) IBOutlet UIButton *setCaptureTargetButton;
    @property (weak, nonatomic) IBOutlet UILabel *statusLabel;
    @property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicatorView;
@property (weak, nonatomic) IBOutlet UIButton *findCameraButton;
@property (weak, nonatomic) IBOutlet UIButton *exitConnectionButton;
- (IBAction)exitConnectionButtonPressed:(id)sender;

@end

