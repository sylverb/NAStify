source 'https://github.com/CocoaPods/Specs.git'

pod 'MAConfirmButton', :git => 'https://github.com/gizmosachin/MAConfirmButton.git', :commit => 'cc15357'
pod 'MKStoreKit', :head
pod 'iRate', '1.11.3'
pod 'box-ios-sdk-v2', :git => 'https://github.com/box/box-ios-sdk-v2.git', :commit => '5b9af5c'
pod 'CocoaHTTPServer', '2.3'
pod 'DACircularProgress', :git => 'https://github.com/danielamitay/DACircularProgress.git', :commit => 'ccc7a2e'
pod 'ELCImagePickerController', :git => 'https://github.com/B-Sides/ELCImagePickerController.git', :commit => 'b57e2f3'
pod 'LTHPasscodeViewController', '3.3.3'
pod 'MBProgressHUD', :git => 'https://github.com/jdg/MBProgressHUD.git', :commit => 'fc1903f'
pod 'objective-zip', '0.8.3'
pod 'OBSlider', '1.1.0'
pod 'PSTCollectionView', '1.2.3'
pod 'Google-API-Client/Drive', '1.0.418'

target 'NAStify' do
    pod 'upnpx', '1.3.6'
    pod 'Google-Mobile-Ads-SDK', '~> 7.0'
    pod 'SSKeychain', :podspec => 'localpods/vendor/SSKeychain.podspec'
    pod 'AFNetworking', :podspec => 'localpods/vendor/AFNetworking.podspec'
    pod 'XMLDictionary', :podspec => 'localpods/vendor/XMLDictionary.podspec'
    pod 'ISO8601DateFormatter', :podspec => 'localpods/vendor/ISO8601DateFormatter.podspec'
end

target 'NAStify-DocProvider' do
    pod 'upnpx', '1.3.6'
    pod 'SSKeychain', :podspec => 'localpods/vendor/SSKeychain.podspec'
    pod 'AFNetworking', :podspec => 'localpods/vendor/AFNetworking.podspec'
    pod 'XMLDictionary', :podspec => 'localpods/vendor/XMLDictionary.podspec'
    pod 'ISO8601DateFormatter', :podspec => 'localpods/vendor/ISO8601DateFormatter.podspec'
end

target 'NAStify-tvOS' do
    platform :tvos, '9.0'
    pod 'upnpx', '1.3.6'
    pod 'SSKeychain', :podspec => 'localpods/vendor/SSKeychain.podspec'
    pod 'AFNetworking', :podspec => 'localpods/vendor/AFNetworking.podspec'
    pod 'XMLDictionary', :podspec => 'localpods/vendor/XMLDictionary.podspec'
    pod 'ISO8601DateFormatter', :podspec => 'localpods/vendor/ISO8601DateFormatter.podspec'
    pod 'xmlrpc'
end
# patched SDWebImage is depending on libRaw, need to find a way to include this in CocoaPod
#pod 'MWPhotoBrowser', :git => 'https://github.com/mwaterfall/MWPhotoBrowser.git', :commit => 'd68f9cd'
#pod 'SDWebImage', :git => 'https://github.com/rs/SDWebImage.git', :commit => 'd2da4d0'

# Apply patches
post_install do |installer|
    puts 'Patching objective-zip to fix characters encoding issue'
    %x(patch Pods/objective-zip/Objective-Zip/ZipFile.m < localpods/patches/ObjectiveZip-encoding-fix.patch)
    puts 'Patching MBProgressHUD to add cancel button'
    %x(patch -Np1 < localpods/patches/MBProgressHUD-add-cancel-button.patch)
    puts 'Patching SSKeychain to add automatic AccessGroup filling'
    %x(patch Pods/SSKeychain/SSKeychain/SSKeychain.m < localpods/patches/SSKeychain-automatic-accessgroup.patch)
    puts 'Patching LTHPasscodeViewController to add automatic AccessGroup filling'
    %x(patch -Np1 < localpods/patches/LTHPasscodeViewController-app-extension.patch)
    puts 'Patching LTHPasscodeViewController to add saving of TouchID use preference'
    %x(patch -Np1 < localpods/patches/LTHPasscodeViewController-touchid-save.patch)
    puts 'Patching MKStoreKit to fix various issues'
    %x(patch -Np1 < localpods/patches/MKStoreKit-fixes.patch)
    puts 'Patching MAConfirmationButton to add dynamic enable method'
    %x(patch -Np1 < localpods/patches/MAConfirmationButton-add-dynamic-enable.patch)
    puts 'Patching AFNetworking to add tvOS support'
    %x(patch -Np1 < localpods/patches/AFNetworking-tvOS-support.patch)
#    puts 'Patching SDWebImage to add RAW images decoding (using libRaw)'
#    %x(patch -Np1 < localpods/patches/SDWebImage-add-libRaw-use.patch)
#    puts 'Patching MWPhotoBrowser to allow to set SDImage download options'
#    %x(patch -Np1 < localpods/patches/MWPhotoBrowser-allow-to-set-download-options.patch)
end
