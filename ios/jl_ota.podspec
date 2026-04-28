Pod::Spec.new do |s|
  s.name             = 'jl_ota'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for Jielong OTA (Over-The-Air) updates.'
  s.description      = <<-DESC
This plugin provides the functionality to perform OTA firmware updates on Jielong devices from within a Flutter application.
                       DESC
  s.homepage         = 'http://yourcompany.com' # 替换为你的实际网站
  s.license          = { :type => 'MIT', :file => '../LICENSE' } # 添加许可证类型
  s.author           = { 'Your Company' => 'your-email@yourcompany.com' } # 替换为你的实际信息
  s.source           = { :git => 'https://github.com/your_username/your_repo.git', :tag => s.version.to_s } # 添加 git 源
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-ObjC'
  }
  s.user_target_xcconfig = { 'OTHER_LDFLAGS' => '-ObjC' }
  s.swift_version = '5.0'

  # 仅保留隐私清单；插件业务文案不再作为资源打入宿主。
  s.resource_bundles = {
    'jl_ota_privacy' => ['Resources/PrivacyInfo.xcprivacy'] # 隐私清单
  }

  s.vendored_frameworks = ['Frameworks/*.framework']

  # 只公开必要的头文件
  s.public_header_files = []
end
