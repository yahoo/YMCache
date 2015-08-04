#
# Be sure to run `pod lib lint YMCache.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "YMCache"
  s.version          = "1.0.0"
  s.summary          = "Fast & simple small object cache. GCD-based and thread-safe."
  s.description      = <<-DESC
                       An optional longer description of YMCache

                       * Markdown format.
                       * Don't worry about the indent, we strip it!
                       DESC
  s.homepage         = "https://github.com/yahoo/YMCache"
  # s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
  s.license          = { :license => 'MIT', :file => 'LICENSE' }
  s.author           = { "adamkaplan" => "adamkaplan@yahoo-inc.com" }
  s.source           = { :git => "https://github.com/yahoo/YMCache.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/adkap'

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'YMCache'

end
