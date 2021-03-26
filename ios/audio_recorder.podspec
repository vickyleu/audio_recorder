#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'audio_recorder'
  s.version          = '0.0.1'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.dependency 'Flutter'

  s.ios.source_files        = 'Classes/**/*','Frameworks/lame.framework/Headers/*.h'
  s.ios.public_header_files = 'Classes/**/*.{h}','Frameworks/lame.framework/Headers/*.{h}'
  s.ios.vendored_frameworks = 'Frameworks/lame.framework'


  s.ios.deployment_target = '9.0'
end

