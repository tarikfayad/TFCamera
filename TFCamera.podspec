#
# Be sure to run `pod lib lint TFCamera.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "TFCamera"
  s.version          = "0.1.13"
  s.summary          = "TFCamera is a very simple camera component based on Snapchat's control scheme for iOS 8+."

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
    "TFCamera is built off AVFoundation with speed and simplicity in mind. It doesn't have a lot of extra bells and whistles, but rather it strives to be a good starting point for any app that's in need of a quick camera component as a jumping off point. For now it includes the following features: pinch to zoom, tap to focus, double tap to swap cameras, hold shutter button to record video, selfie flash, and a basic shutter animation."
    DESC

  s.homepage         = "https://github.com/tarikfayad/TFCamera"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = 'MIT'
  s.author           = { "Tarik Fayad" => "tarikfayad@gmail.com" }
  s.source           = { :git => "https://github.com/tarikfayad/TFCamera.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/tarikfayad'

  s.platform     = :ios, '8.4'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
  s.resource_bundles = {
    'TFCamera' => ['Pod/Assets/*']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'AVFoundation', 'AssetsLibrary', 'CoreTelephony'
  s.dependency 'pop', '~> 1.0'
  s.dependency 'JWGCircleCounter', '~> 0.2'
end
