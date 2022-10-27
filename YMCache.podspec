Pod::Spec.new do |s|
  s.name             = 'YMCache'
  s.version          = '2.2.0'
  s.summary          = 'Fast & simple small object cache. GCD-based and thread-safe.'
  s.homepage         = 'https://github.com/yahoo/YMCache'
  s.license          = 'MIT'
  s.author           = { 'adamkaplan' => 'adamkaplan@yahoo-inc.com' }
  s.source           = { :git => 'https://github.com/yahoo/YMCache.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '3.0'

  s.source_files = 'YMCache/*.{h,m,swift}'
  s.swift_versions = [ '5.0', '5.2' ]
end
