#
# Be sure to run `pod lib lint TFCamera.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "TFCamera"
  s.version          = "0.1.9"
  s.summary          = "A simple drop in camera component."

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = "Based on the Snapchat camera, TFCamera is a very simple camera component that takes both photos and videos with both camera on the iPhone. It includes doubletapping on the screen to swap cameras, selfie flash, and tap to focus."

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
