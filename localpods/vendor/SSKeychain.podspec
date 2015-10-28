Pod::Spec.new do |spec|
  spec.name         = 'SSKeychain'
  spec.version      = '1.2.2'
  spec.summary      = 'Simple Cocoa wrapper for the keychain that works on Mac and iOS.'
  spec.homepage     = 'https://github.com/soffes/sskeychain'
  spec.author       = { 'Sam Soffes' => 'sam@soff.es' }
  spec.ios.deployment_target = "6.1"
  spec.osx.deployment_target = "10.6"
  spec.tvos.deployment_target = "9.0"
  spec.source       = { :git => 'https://github.com/soffes/sskeychain.git', :tag => "v#{spec.version}" }
  spec.description  = 'SSKeychain is a simple utility class for making the system keychain less sucky.'
  spec.ios.source_files =  'SSKeychain/*.{h,m}'
  spec.osx.source_files =  'SSKeychain/*.{h,m}'
  spec.tvos.source_files = 'SSKeychain/*.{h,m}'
  spec.ios.public_header_files = 'SSKeychain/*.h'
  spec.osx.public_header_files = 'SSKeychain/*.h'
  spec.tvos.public_header_files = 'SSKeychain/*.h'
  spec.requires_arc = true
  spec.license      = { :type => 'MIT', :file => 'LICENSE' }
  spec.frameworks = 'Security', 'Foundation'
end
