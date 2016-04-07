# TFCamera
TFCamera is a very simple camera component based on Snapchat's control scheme for iOS 8+.

### Version
0.1.10

### Tech

TFCamera is built off AVFoundation with speed and simplicity in mind. It doesn't have a lot of extra bells and whistles, but rather strives to be a good starting point for any app that's in need of a quick camera component as a jumping off point. For now it includes the following features:
- pinch to zoom
- tap to focus
- double tap to swap cameras
- hold shutter button to record video
- selfie flash
- a basic shutter animation

TFCamera is dependant on two other Cocoapods to function correctly:

* [pop] - Facebook's awesome animation framework
* [JWGCircleCounter] - a simple circle counter that's incredibly convenient and easy to use

### Installation

TFCamera is available through [CocoaPods]. To install it, simply add the following line to your Podfile:

```sh
pod "TFCamera"
```

### Usage

Getting started with TFCamera is obscenely easy! Simply instantiate the camera ViewController and set its delegate with the following code and then present it wherever you'd like to use it (works great as a view in a UIPageViewController):
```
TFCameraViewController *cameraVC = [[TFCameraViewController alloc] initWithInterface];
cameraVC.delegate = self;
```

Then call the following delegate methods:
```
- (void)cameraDidTakePhoto:(UIImage *)photo;
- (void)cameraDidTakeVideo:(NSURL *)videoURL;
```
Once a photo has been taken a ```UIImage``` will be passed back (selfies are already flipped to match what the user sees on their screen so no need to worry about that). Likewise, once a video is recorded an ```NSURL``` to its location will be passed back. TFCamera always overrites the video file it just took, so need to worry about it taking up a large amount of space on your user's device.

It also allows for easily changing the interface color (just set the ```appColor``` property after instantiation). Feel free to register it for a color change notififcation as well if you want the user to be able to change the ui color on the fly with the following method:
```
- (void) registerCameraForColorChangeNotification: (NSString *) notificationString;
```

### Customization
TFCamera has the following properties you can set to customize the camera functionality and appearance (not many yet, but more coming soon!).
```
@property (nonatomic) BOOL enableDoubleTapSwitch;
@property (nonatomic) BOOL enableSelfieFlash;

@property (nonatomic) CGFloat maxVideoLength; //Default is 16 seconds
@property (nonatomic) CGFloat shutterAnimationSpeed; //Default is .15 seconds 

@property (strong, nonatomic) UIColor *appColor;
```

### Author
Tarik Fayad, [tarikfayad@gmail.com]

### Todos

 - Write Tests
 - Allow More UI Customization
 - Add Code Comments
 - Add Night Mode

License
----
TFCamera is available under the MIT license. See the LICENSE file for more info.

[//]: # (These are reference links used in the body of this note and get stripped out when the markdown processor does its job. There is no need to format nicely because it shouldn't be seen. Thanks SO - http://stackoverflow.com/questions/4823468/store-comments-in-markdown-syntax)


   [pop]: <https://github.com/facebook/pop>
   [JWGCircleCounter]: <https://github.com/johngraham262/JWGCircleCounter>
   [CocoaPods]: <cocoapods.org>
   [tarikfayad@gmail.com]: <mailto:tarikfayad@gmail.com>
