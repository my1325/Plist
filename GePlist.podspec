Pod::Spec.new do |s|

 s.name             = "GePlist"
 s.version           = "1.0.0"
 s.summary         = "provide tool to read or write property list file and json file"
 s.homepage        = "https://github.com/my1325/GeSwift.git"
 s.license            = "MIT"
 s.platform          = :ios, "13.0"
 s.authors           = { "mayong" => "1173962595@qq.com" }
 s.source             = { :git => "https://github.com/my1325/Plist.git", :tag => "#{s.version}" }
 s.swift_version = '5'
 s.default_subspecs = 'Plist'

 s.subspec 'Plist' do |ss|
    ss.source_files = [
      'Plist/*.swift',
      'DataWriter/*.swift'
   ]
 end

 s.subspec 'HandyJSON' do |ss|
    ss.source_files = "PlistHandyJSONSupport/*.swift"
    ss.dependency 'GePlist/Plist'
    ss.dependency 'HandyJSON'
 end
end