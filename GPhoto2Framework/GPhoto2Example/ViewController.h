//
//  ViewController.h
//  GPhoto2Example
//
//  Created by Hendrik Holtmann on 21.10.18.
//  Copyright © 2019 Hendrik Holtmann. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

- (IBAction)connectTouchedPTP:(id)sender;
- (IBAction)connectLumixTouched:(id)sender;
- (IBAction)listTouched:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *connectButtonPTP;
@property (weak, nonatomic) IBOutlet UIButton *connectButtonLumix;
@property (weak, nonatomic) IBOutlet UIButton *listButton;

@property (weak, nonatomic) IBOutlet UITextField *ipTextField;
@property (weak, nonatomic) IBOutlet UITextView *consoleTextView;

@end

