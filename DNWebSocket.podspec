#
# Be sure to run `pod lib lint DNWebSocket.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DNWebSocket'
  s.version          = '1.0.0'
  s.summary          = 'Pure Swift WebSocket Library'
  s.description      = <<-DESC
    Object-Oriented, Swift-style WebSocket Library (RFC 6455) for Swift-compatible Platforms.
    Conforms to all necessary Autobahn fuzzing tests.
                       DESC

  s.homepage         = 'https://github.com/GlebRadchenko/DNWebSocket'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Gleb Radchenko' => 'gleb.radchenko@activewindow.dk' }
  s.source           = { :git => 'https://github.com/GlebRadchenko/DNWebSocket.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.source_files = 'Sources/*'
end
