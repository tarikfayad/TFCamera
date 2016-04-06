//
//  TFCameraViewController.m
//  camera
//
//  Created by Tarik Fayad on 4/2/16.
//  Copyright © 2016 Tarik Fayad. All rights reserved.
//

#import "TFCameraViewController.h"
#import "TFCameraFocusSquare.h"
#import "UIImage+FixOrientation.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreTelephony/CTCallCenter.h>
#import <CoreTelephony/CTCall.h>
#import <JWGCircleCounter/JWGCircleCounter.h>
#import <pop/POP.h>

#define VIDEO_LENGTH 16
#define SHUTTER_SPEED .15f

@interface TFCameraViewController () <AVCaptureFileOutputRecordingDelegate>

//IB Outlets
@property (weak, nonatomic) IBOutlet JWGCircleCounter *shutterButtonTimer;
@property (weak, nonatomic) IBOutlet UIView *shutterButtonOutline;
@property (weak, nonatomic) IBOutlet UIButton *shutterButton;
@property (weak, nonatomic) IBOutlet UIButton *flashButton;
@property (weak, nonatomic) IBOutlet UIButton *swapCameraButton;

//AVFoundation Properties
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *photoPreview;
@property (strong, nonatomic) AVCaptureDevice *device;
@property (strong, nonatomic, retain) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) AVCaptureMovieFileOutput *movieOutput;

@property (strong, nonatomic) AVAssetWriter *movieWriter;
@property (strong, nonatomic) AVAssetWriterInput *movieWriterVideoInput;
@property (strong, nonatomic) AVAssetWriterInput *movieWriterAudioInput;

@property (strong, nonatomic) UIImage *capturedImage;

//Helper Views
@property (strong, nonatomic) TFCameraFocusSquare *camFocus;

//Booleans for State
@property (nonatomic) BOOL isVideoCamera;
@property (nonatomic) BOOL selfieMode;

//IBActions for Easy Reference
- (IBAction)swapCameraButton:(id *)sender;
- (IBAction)shutterButton:(UIButton *)sender;
- (IBAction)flashButton:(UIButton *)sender;

@end

@implementation TFCameraViewController

#pragma mark - Initializers
- (instancetype) initWithInterface
{
    TFCameraViewController *cameraViewController = [[TFCameraViewController alloc] initWithNibName:@"CameraOverlay" bundle:[self podBundle]];
    return cameraViewController;
}

#pragma mark - View Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (![self checkForCameraAccess]) {
        //Request audio and video access.
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:nil];
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:nil];
    } else {
        //Setup everything else as normal
        self.selfieMode = NO;
        self.enableSelfieFlash = YES;
        self.enableDoubleTapSwitch = YES;
        [self setupView];
        [self setupCaptureSession];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRotateFromInterfaceOrientation:) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    
    //Adding the longpress gesture recognizer for video recording
    UILongPressGestureRecognizer *videoLongpress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleVideoLongpress:)];
    videoLongpress.minimumPressDuration = .75;
    [self.shutterButton addGestureRecognizer:videoLongpress];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.photoPreview.frame = self.view.bounds;
    [self setupShutterButtonOutline];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if ([UIApplication sharedApplication].statusBarHidden == NO)
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    
    [self.navigationController.navigationBar setHidden:YES];
    [self.navigationController.navigationBar setTranslucent:YES];
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device.flashMode == AVCaptureFlashModeOff) {
        NSString *imagePath = [[self podBundle] pathForResource:@"camera-flash" ofType:@"png"];
        [self.flashButton setImage:[UIImage imageWithContentsOfFile:imagePath] forState:UIControlStateNormal];
    } else {
        NSString *imagePath = [[self podBundle] pathForResource:@"camera-flash-on" ofType:@"png"];
        [self.flashButton setImage:[UIImage imageWithContentsOfFile:imagePath] forState:UIControlStateNormal];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if ([UIApplication sharedApplication].statusBarHidden == YES) [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    [self.navigationController.navigationBar setHidden:NO];
    [self.navigationController.navigationBar setTranslucent:NO];
}

#pragma mark - View Helper Methods

- (void) setupView
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    self.isVideoCamera = NO;
    self.capturedImage = nil;
    
    if (self.enableDoubleTapSwitch) {
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(swapCameraButton:)];
        doubleTap.numberOfTapsRequired = 2;
        
        [self.view addGestureRecognizer:doubleTap];
        
        [self setupFocusTapWithDoubleTapSwap:doubleTap];
    } else {
        [self setupFocusTapWithDoubleTapSwap:nil];
    }
    
    [self setupPinchToZoomGesture];
}

- (void) setupFocusTapWithDoubleTapSwap: (UITapGestureRecognizer *) swapGesture
{
    UITapGestureRecognizer *focusTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusCamera:)];
    focusTap.numberOfTapsRequired = 1;
    if (swapGesture) [focusTap requireGestureRecognizerToFail:swapGesture];
    [self.view addGestureRecognizer:focusTap];
}

- (void) setupPinchToZoomGesture
{
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchToZoomRecognizer:)];
    [self.view addGestureRecognizer:pinch];
}


- (BOOL) checkForCameraAccess
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusDenied || status == AVAuthorizationStatusRestricted || status == AVAuthorizationStatusNotDetermined) return NO;
    return YES;
}

- (void) setupCaptureSession
{
    self.captureSession = [AVCaptureSession new];
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [self.device lockForConfiguration:nil];
    
    if ([self.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
        self.device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    
    else if ([self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
        self.device.focusMode = AVCaptureFocusModeAutoFocus;
    
    [self.device unlockForConfiguration];
    
    AVCaptureInput *input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    
    [self.captureSession addInput:input];
    
    AVCaptureVideoDataOutput *output = [AVCaptureVideoDataOutput new];
    [self. captureSession addOutput:output];
    
    self.photoPreview = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    self.photoPreview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:self.photoPreview];
    self.photoPreview.zPosition = -100.0; // Always make sure the camera live preview is farthest "back"
    
    AVCaptureStillImageOutput *tmpOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
    tmpOutput.outputSettings = outputSettings;
    [self.captureSession addOutput:tmpOutput];
    self.stillImageOutput = tmpOutput;
    
    [self.captureSession startRunning];
}

#pragma mark - Camera Methods
- (void)focusCamera:(UITapGestureRecognizer *)sender {
    CGPoint touchPoint = [sender locationInView:self.view];
    [self focus:touchPoint];
    
    if (self.camFocus)
    {
        [self.camFocus removeFromSuperview];
    }
    
    self.camFocus = [[TFCameraFocusSquare alloc]initWithFrame:CGRectMake(touchPoint.x-40, touchPoint.y-40, 80, 80)];
    [self.camFocus setBackgroundColor:[UIColor clearColor]];
    [self.view addSubview:self.camFocus];
    [self.camFocus setNeedsDisplay];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:1.5];
    [self.camFocus setAlpha:0.0];
    [UIView commitAnimations];
}

- (void) focus:(CGPoint) aPoint;
{
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        AVCaptureDevice *device = [captureDeviceClass defaultDeviceWithMediaType:AVMediaTypeVideo];
        if([device isFocusPointOfInterestSupported] &&
           [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            CGPoint focusPoint = [self.photoPreview captureDevicePointOfInterestForPoint:aPoint];
            if([device lockForConfiguration:nil]) {
                [device setFocusPointOfInterest:CGPointMake(focusPoint.x,focusPoint.y)];
                [device setFocusMode:AVCaptureFocusModeAutoFocus];
                if ([device isExposureModeSupported:AVCaptureExposureModeAutoExpose]){
                    [device setExposureMode:AVCaptureExposureModeAutoExpose];
                }
                [device unlockForConfiguration];
            }
        }
    }
}

-(void) handlePinchToZoomRecognizer:(UIPinchGestureRecognizer*)pinchRecognizer {
    const CGFloat pinchVelocityDividerFactor = 50.0f;
    
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        AVCaptureDevice *device = [captureDeviceClass defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (pinchRecognizer.state == UIGestureRecognizerStateChanged) {
            NSError *error = nil;
            if ([device lockForConfiguration:&error]) {
                CGFloat desiredZoomFactor = device.videoZoomFactor + atan2f(pinchRecognizer.velocity, pinchVelocityDividerFactor);
                // Check if desiredZoomFactor fits required range from 1.0 to activeFormat.videoMaxZoomFactor
                device.videoZoomFactor = MAX(1.0, MIN(desiredZoomFactor, device.activeFormat.videoMaxZoomFactor));
                [device unlockForConfiguration];
            } else {
                NSLog(@"error: %@", error);
            }
        }
    }
}

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) return device;
    }
    return nil;
}

#pragma mark - Videocamera Methods
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    self.movieWriter = [AVAssetWriter assetWriterWithURL:fileURL fileType:AVFileTypeMPEG4 error:nil];
    [self.movieWriter setShouldOptimizeForNetworkUse:YES];
    
    NSDictionary *videoCleanApertureSettings = @{
                                                 AVVideoCleanApertureWidthKey: [NSNumber numberWithFloat:self.view.frame.size.width],
                                                 AVVideoCleanApertureHeightKey: [NSNumber numberWithFloat:self.view.frame.size.height],
                                                 AVVideoCleanApertureHorizontalOffsetKey: [NSNumber numberWithInt:10],
                                                 AVVideoCleanApertureVerticalOffsetKey: [NSNumber numberWithInt:10],
                                                 };
    
    NSDictionary *videoCompressionSettings = @{
                                               AVVideoAverageBitRateKey: [NSNumber numberWithFloat:1250000.0f],
                                               AVVideoMaxKeyFrameIntervalKey: [NSNumber numberWithInteger:1],
                                               AVVideoProfileLevelKey: AVVideoProfileLevelH264Baseline30,
                                               AVVideoCleanApertureKey: videoCleanApertureSettings,
                                               };
    
    NSDictionary *videoSettings = @{AVVideoCodecKey: AVVideoCodecH264,
                                    AVVideoWidthKey: [NSNumber numberWithFloat:self.view.frame.size.width],
                                    AVVideoHeightKey: [NSNumber numberWithFloat:self.view.frame.size.height],
                                    AVVideoCompressionPropertiesKey: videoCompressionSettings,
                                    };
    
    self.movieWriterVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    self.movieWriterVideoInput.expectsMediaDataInRealTime = YES;
    [self.movieWriter addInput:self.movieWriterVideoInput];
    
    NSDictionary *audioSettings = @{AVFormatIDKey: [NSNumber numberWithInteger:kAudioFormatMPEG4AAC],
                                    AVSampleRateKey: [NSNumber numberWithFloat:44100.0],
                                    AVNumberOfChannelsKey: [NSNumber numberWithInteger:1],
                                    };
    
    self.movieWriterAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    self.movieWriterAudioInput.expectsMediaDataInRealTime = YES;
    [self.movieWriter addInput:self.movieWriterAudioInput];
    
    
    [self.movieWriter startWriting];
}

-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    //Reset progress bar
    [self.movieWriterVideoInput markAsFinished];
    [self.movieWriterAudioInput markAsFinished];
    [self.movieWriter finishWritingWithCompletionHandler:^{
        if ([self.delegate respondsToSelector:@selector(cameraDidTakeVideo:)]) return [self.delegate cameraDidTakeVideo:self.movieWriter.outputURL];
    }];
}

#pragma mark - UIButton methods
- (IBAction)swapCameraButton:(id *)sender {
    //Change camera source
    if(self.captureSession)
    {
        //Start the screen flash
        [self triggerShutterAnimation];
        
        //Indicate that some changes will be made to the session
        [self.captureSession beginConfiguration];
        
        //Remove existing input
        AVCaptureInput* currentCameraInput = [self.captureSession.inputs objectAtIndex:0];
        for (AVCaptureInput *captureInput in self.captureSession.inputs) {
            [self.captureSession removeInput:captureInput];
        }
        
        //Get new input
        AVCaptureDevice *newCamera = nil;
        if(((AVCaptureDeviceInput*)currentCameraInput).device.position == AVCaptureDevicePositionBack)
        {
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
            self.selfieMode = YES;
        }
        else
        {
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
            self.selfieMode = NO;
        }
        
        //Add input to session
        AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newCamera error:nil];
        [self.captureSession addInput:newVideoInput];
        
        if (self.isVideoCamera) {
            //Add mic input to the session
            AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            AVCaptureInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
            [self.captureSession addInput:audioInput];
        }
        
        //Commit all the configuration changes at once
        [self.captureSession commitConfiguration];
    }
}

- (IBAction)shutterButton:(UIButton *)sender {
    if (!self.isVideoCamera) {
        AVCaptureConnection *videoConnection = nil;
        for (AVCaptureConnection *connection in self.stillImageOutput.connections)
        {
            for (AVCaptureInputPort *port in [connection inputPorts])
            {
                if ([[port mediaType] isEqual:AVMediaTypeVideo] )
                {
                    videoConnection = connection;
                    break;
                }
            }
            if (videoConnection) { break; }
        }
        
        if([videoConnection isVideoOrientationSupported]) [videoConnection setVideoOrientation:[self convertDeviceOrientationToVideoOrientation:[UIDevice currentDevice].orientation]];
        
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (self.selfieMode && self.enableSelfieFlash && device.flashMode == AVCaptureFlashModeOn) [self triggerSelfieFlash];
        [self triggerShutterAnimation];
        [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
         {
             NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
             UIImage *image = [[UIImage alloc] initWithData:imageData];
             [image fixOrientation];
             self.capturedImage = image;
             
             if (self.selfieMode) {
                 UIImage* flippedImage = [UIImage imageWithCGImage:image.CGImage
                                                             scale:image.scale
                                                       orientation:UIImageOrientationLeftMirrored];
                 self.capturedImage = flippedImage;
             }
             
             if ([self.delegate respondsToSelector:@selector(cameraDidTakePhoto:)]) return [self.delegate cameraDidTakePhoto:self.capturedImage];
         }];
    }
}

- (AVCaptureVideoOrientation) convertDeviceOrientationToVideoOrientation: (UIDeviceOrientation) orientation {
    
    switch (orientation) {
        case UIDeviceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            return AVCaptureVideoOrientationPortrait;
            break;
    }
}

- (void) triggerShutterAnimation
{
    //get the application window
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    
    // Create a empty view with the color black.
    UIView *flashView = [[UIView alloc] initWithFrame:window.bounds];
    flashView.backgroundColor = [UIColor blackColor];
    flashView.alpha = 1.0;
    
    // Add the flash view to the window
    [window addSubview:flashView];
    
    // Fade it out and remove after animation.
    [UIView animateWithDuration:SHUTTER_SPEED animations:^{
        flashView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [flashView removeFromSuperview];
    }];
}

- (void) toggleVideoRecording {
    if (self.isVideoCamera) {
        if (!self.movieOutput.isRecording) {
            NSURL *movieOutputURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), @"output.mp4"]];
            [self.movieOutput startRecordingToOutputFileURL:movieOutputURL recordingDelegate:self];
            [self.shutterButtonTimer startWithSeconds:VIDEO_LENGTH];
        } else {
            [self.movieOutput stopRecording];
            [self.shutterButtonTimer startWithSeconds:VIDEO_LENGTH];
            [self.shutterButtonTimer reset];
        }
    }
}

- (IBAction)flashButton:(UIButton *)sender {
    AVCaptureInput* currentCameraInput = [self.captureSession.inputs objectAtIndex:0];
    if (((AVCaptureDeviceInput*)currentCameraInput).device.position == AVCaptureDevicePositionBack) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([device hasFlash]) {
            [device lockForConfiguration:nil];
            
            if (device.flashMode == AVCaptureFlashModeOff) {
                NSString *imagePath = [[self podBundle] pathForResource:@"camera-flash-on" ofType:@"png"];
                [self.flashButton setImage:[UIImage imageWithContentsOfFile:imagePath] forState:UIControlStateNormal];
                [device setFlashMode:AVCaptureFlashModeOn];
            } else {
                NSString *imagePath = [[self podBundle] pathForResource:@"camera-flash" ofType:@"png"];
                [self.flashButton setImage:[UIImage imageWithContentsOfFile:imagePath] forState:UIControlStateNormal];
                [device setFlashMode:AVCaptureFlashModeOff];
            }
            [device unlockForConfiguration];
        }
    }
}

- (void) triggerSelfieFlash
{
    //get the application window
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    
    //Adjust screen brightness
    CGFloat currentScreenBrightness = [UIScreen mainScreen].brightness;
    [[UIScreen mainScreen] setBrightness:1.0];
    // Create a empty view with the color white.
    UIView *flashView = [[UIView alloc] initWithFrame:window.bounds];
    flashView.backgroundColor = [UIColor whiteColor];
    flashView.alpha = 1.0;
    
    // Add the flash view to the window
    [window addSubview:flashView];
    
    // Fade it out and remove after animation.
    [UIView animateWithDuration:0.05 animations:^{
        flashView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [flashView removeFromSuperview];
        [[UIScreen mainScreen] setBrightness:currentScreenBrightness];
    }];
}

- (void) handleVideoLongpress: (UILongPressGestureRecognizer *)longpress {
    //Stopping video if the user is on a phone call since iOS wont let it work
    if (![self isOnPhoneCall]) {
        if (longpress.state == UIGestureRecognizerStateBegan) {
            if (!self.isVideoCamera) {
                self.shutterButton.backgroundColor = [UIColor redColor];
                [self.shutterButtonTimer setHidden:NO];
                
                if(self.captureSession) {
                    //Indicate that some changes will be made to the session
                    [self.captureSession beginConfiguration];
                    self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
                    
                    AVCaptureInput* currentCameraInput = [self.captureSession.inputs objectAtIndex:0];
                    for (AVCaptureInput *captureInput in self.captureSession.inputs) {
                        [self.captureSession removeInput:captureInput];
                    }
                    
                    
                    //Get currently selected camera and use for input
                    AVCaptureDevice *videoCamera = nil;
                    if(((AVCaptureDeviceInput*)currentCameraInput).device.position == AVCaptureDevicePositionBack)
                    {
                        videoCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
                    }
                    else
                    {
                        videoCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
                    }
                    
                    //Add input to session
                    AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoCamera error:nil];
                    [self.captureSession addInput:newVideoInput];
                    
                    //Add mic input to the session
                    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
                    AVCaptureInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
                    if (audioInput) {
                        [self.captureSession addInput:audioInput];
                    } else {
                        [[[UIAlertView alloc] initWithTitle:@"No Sound!" message:@"It looks like we don't have access to your microphone. Please enable it in your device's settings to record video." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
                        self.shutterButton.backgroundColor = [UIColor whiteColor];
                        return;
                    }
                    
                    //Add movie output to session
                    for (AVCaptureOutput *output in self.captureSession.outputs) {
                        [self.captureSession removeOutput:output];
                    }
                    
                    self.movieOutput = [AVCaptureMovieFileOutput new];
                    int32_t preferredTimeScale = 30; //Frames per second
                    self.movieOutput.maxRecordedDuration = CMTimeMakeWithSeconds(VIDEO_LENGTH, preferredTimeScale); //Setting the max video length
                    self.movieOutput.movieFragmentInterval = kCMTimeInvalid; // Makes audio work longer than 10 seconds: http://stackoverflow.com/questions/26768987/avcapturesession-audio-doesnt-work-for-long-videos
                    [self.captureSession addOutput:self.movieOutput];
                    
                    //Commit all the configuration changes at once
                    [self.captureSession commitConfiguration];
                    
                    self.isVideoCamera = YES;
                    
                    [self toggleVideoRecording];
                }
            }
        } else if (longpress.state == UIGestureRecognizerStateEnded) {
            if (self.isVideoCamera) {
                self.shutterButton.backgroundColor = [UIColor whiteColor];
                
                //Change camera source
                if(self.captureSession) {
                    //Indicate that some changes will be made to the session
                    [self.captureSession beginConfiguration];
                    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
                    
                    //Remove existing video/audio inputs
                    AVCaptureInput* currentCameraInput = [self.captureSession.inputs objectAtIndex:0];
                    for (AVCaptureInput *captureInput in self.captureSession.inputs) {
                        [self.captureSession removeInput:captureInput];
                    }
                    
                    //Remove existing outputs
                    for (AVCaptureOutput *output in self.captureSession.outputs) {
                        [self.captureSession removeOutput:output];
                    }
                    [self.captureSession addOutput:self.stillImageOutput];
                    
                    //Get new input
                    AVCaptureDevice *newCamera = nil;
                    if(((AVCaptureDeviceInput*)currentCameraInput).device.position == AVCaptureDevicePositionBack)
                        newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
                    else
                        newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
                    
                    //Add input to session
                    AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newCamera error:nil];
                    [self.captureSession addInput:newVideoInput];
                    
                    //Commit all the configuration changes at once
                    [self.captureSession commitConfiguration];
                    [self.shutterButtonTimer setHidden:YES];
                    self.isVideoCamera = NO;
                    
                    [self toggleVideoRecording];
                }
            }
        }
    } else {
        UIAlertController *phoneCallAlert = [UIAlertController alertControllerWithTitle:@"No Video Access!" message:@"Hey! It looks like you're on the phone. Unfortunately we can't take video until you hang up." preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [phoneCallAlert addAction:cancelAction];
        [self presentViewController:phoneCallAlert animated:YES completion:nil];
    }
}

#pragma mark - Animation Methods
-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (UIDeviceOrientationIsPortrait(deviceOrientation))
        [self portraitButtonAnimations];
    
    else if (UIDeviceOrientationIsLandscape(deviceOrientation))
        [self landscapeButtonAnimations];
}

- (void) portraitButtonAnimations
{
    //Animate grid, flash, and swap camera buttons
    NSArray *buttonArray = @[self.flashButton, self.swapCameraButton];
    
    for (UIButton *button in buttonArray) {
        CALayer *buttonLayer = button.layer;
        
        [buttonLayer pop_removeAllAnimations];
        POPSpringAnimation *rotation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
        rotation.toValue = @(0);
        
        [buttonLayer pop_addAnimation:rotation forKey:@"rotation"];
    }
}


- (void) landscapeButtonAnimations
{
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    
    //Animate grid, flash, and swap camera buttons
    NSArray *buttonArray = @[self.flashButton, self.swapCameraButton];
    
    for (UIButton *button in buttonArray) {
        CALayer *buttonLayer = button.layer;
        
        [buttonLayer pop_removeAllAnimations];
        POPSpringAnimation *rotation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
        if (deviceOrientation == UIDeviceOrientationLandscapeLeft) {
            rotation.toValue = @(M_PI_2);
        } else {
            rotation.toValue = @(-M_PI_2);
        }
        
        [buttonLayer pop_addAnimation:rotation forKey:@"rotation"];
    }
}


#pragma mark - shutterbutton outline methods
- (void) setupShutterButtonOutline
{
    self.shutterButton.layer.cornerRadius = 42.0f;
    self.shutterButtonOutline.layer.cornerRadius = 50.0f;
    self.shutterButtonOutline.layer.borderColor = [UIColor whiteColor].CGColor;
    self.shutterButtonOutline.layer.borderWidth = 2.0f;
    
    self.shutterButtonTimer.circleColor = [UIColor whiteColor];
    self.shutterButtonTimer.circleFillColor = [UIColor clearColor];
    self.shutterButtonTimer.circleBackgroundColor = [UIColor clearColor];
}

#pragma mark - Helpers
- (NSBundle *) podBundle
{
    NSBundle *podBundle = [NSBundle bundleForClass:self.classForCoder];
    NSURL *bundleURL = [podBundle URLForResource:@"TFCamera" withExtension:@"bundle"];
    
    return [NSBundle bundleWithURL:bundleURL];
}

-(bool)isOnPhoneCall {
    // Returns TRUE/YES if the user is currently on a phone call
    CTCallCenter *callCenter = [CTCallCenter new];
    for (CTCall *call in callCenter.currentCalls)  {
        if (call.callState == CTCallStateConnected) {
            return YES;
        }
    }
    return NO;
}

@end