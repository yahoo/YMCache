Pod::Spec.new do |s|
  s.name             = "YMCache"
  s.version          = "1.0.0"
  s.summary          = "Fast & simple small object cache. GCD-based and thread-safe."
  s.homepage         = "https://github.com/yahoo/YMCache"
  s.license          = 'MIT'
  s.author           = { "adamkaplan" => "adamkaplan@yahoo-inc.com" }
  s.source           = { :git => "https://github.com/yahoo/YMCache.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/adkap'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'YMCache/*.[h,m]'
end
