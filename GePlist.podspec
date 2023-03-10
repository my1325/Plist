Pod::Spec.new do |s|

 s.name             = "GePlist"
 s.version           = "0.0.5"
 s.summary         = "provide tool to read or write property list file and json file"
 s.homepage        = "https://github.com/my1325/GeSwift.git"
 s.license            = "MIT"
 s.platform          = :ios, "11.0"
 s.authors           = { "mayong" => "1173962595@qq.com" }
 s.source             = { :git => "https://github.com/my1325/Plist.git", :tag => "#{s.version}" }
 s.swift_version = '5'
 s.default_subspecs = 'Plist'

 s.subspec 'FilePath' do |ss|
    ss.source_files = 'FilePath/*.swift'
 end

 s.subspec 'DataWriter' do |ss|
    ss.source_files = 'DataWriter/*.swift'
    ss.dependency 'GePlist/FilePath'
 end 

 s.subspec 'Plist' do |ss|
    ss.source_files = 'Plist/*.swift'
    ss.dependency 'GePlist/FilePath'
    ss.dependency 'GePlist/DataWriter'
 end

 s.subspec 'HandyJSON' do |ss|
    ss.source_files = "PlistHandyJSONSupport/*.swift"
    ss.dependency 'GePlist/Plist'
    ss.dependency 'HandyJSON', '5.0.2'
 end
end