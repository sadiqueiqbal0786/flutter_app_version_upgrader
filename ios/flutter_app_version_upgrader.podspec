#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_app_version_upgrader.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_app_version_upgrader'
  s.version          = '0.2.2'
  s.summary          = 'Remote-controlled app version management for Flutter.'
  s.description      = <<-DESC
Reads the installed version, caches the last known version policy and opens
the App Store listing. The decision logic lives in Dart.
                       DESC
  s.homepage         = 'https://github.com/sadiqueiqbal0786/flutter_app_version_upgrader'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Sadique Iqbal' => 'sadiqueiqbal.si@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_app_version_upgrader/Sources/flutter_app_version_upgrader/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_app_version_upgrader_privacy' => ['flutter_app_version_upgrader/Sources/flutter_app_version_upgrader/PrivacyInfo.xcprivacy']}
end
