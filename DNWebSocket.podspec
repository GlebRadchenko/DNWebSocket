Pod::Spec.new do |s|
  s.name             = 'DNWebSocket'
  s.version          = '1.1.0'
  s.summary          = 'Pure Swift WebSocket Library'
  s.description      = <<-DESC
    Object-Oriented, Swift-style WebSocket Library (RFC 6455) for Swift-compatible Platforms.
    Conforms to all necessary Autobahn fuzzing tests.
                       DESC

  s.homepage         = 'https://github.com/GlebRadchenko/DNWebSocket'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Gleb Radchenko' => 'gleb.radchenko3@gmail.com' }
  s.source           = { :git => 'https://github.com/GlebRadchenko/DNWebSocket.git', :tag => s.version.to_s }

  s.swift_version = '4.2'

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.source_files = 'Sources/**/*.swift'
  s.pod_target_xcconfig = {'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/Sources/CZLib/**'}
  s.preserve_path = 'Sources/CZLib/**'

end
