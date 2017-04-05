Pod::Spec.new do |s|
  s.name         = "RDAmplitude"
  s.version      = "3.8.3"
  s.summary      = "Amplitude mobile analytics iOS SDK."
  s.homepage     = "https://amplitude.com"
  s.license      = { :type => "MIT" }
  s.author       = { "Amplitude" => "dev@amplitude.com" }
  s.source       = { :git => "https://github.com/falconser/RDAmplitude.git", :tag => "v3.8.3" }
  s.platform     = :ios, '5.0'
  s.platform     = :osx, '10.9'
  s.source_files = 'Amplitude/*.{h,m}'
  s.requires_arc = true
  s.library 	 = 'sqlite3.0'
end
