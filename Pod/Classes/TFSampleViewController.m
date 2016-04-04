//
//  TFSampleViewController.m
//  camera
//
//  Created by Tarik Fayad on 4/2/16.
//  Copyright © 2016 Tarik Fayad. All rights reserved.
//

#import "TFSampleViewController.h"
#import "TFCameraViewController.h"

@interface TFSampleViewController () <TFCameraViewControllerDelegate>

@end

@implementation TFSampleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

-(void)cameraDidTakePhoto:(UIImage *)photo {
    NSLog(@"image: %@", photo);
}

- (void)cameraDidTakeVideo:(NSURL *)videoURL {
    NSLog(@"video URL: %@", videoURL);
}

- (IBAction)showCamera:(id)sender {
    TFCameraViewController *cameraVC = [[TFCameraViewController alloc] initWithNibName:@"CameraOverlay" bundle:nil];
    cameraVC.delegate = self;
    [self presentViewController:cameraVC animated:YES completion:nil];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
