Pod::Spec.new do |s|
  s.name             = 'YMCache'
  s.version          = '2.1.1'
  s.summary          = 'Fast & simple small object cache. GCD-based and thread-safe.'
  s.homepage         = 'https://github.com/yahoo/YMCache'
  s.license          = 'MIT'
  s.author           = { 'adamkaplan' => 'adamkaplan@yahoo-inc.com' }
  s.source           = { :git => 'https://github.com/yahoo/YMCache.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/adkap'

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '11.0'
  s.watchos.deployment_target = '3.0'

  s.requires_arc = true

  s.source_files = 'YMCache/*.[h,m]'
end
