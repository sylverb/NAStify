source 'https://github.com/CocoaPods/Specs.git'

pod 'MAConfirmButton', :git => 'https://github.com/gizmosachin/MAConfirmButton.git', :commit => '23ce343'
pod 'MKStoreKit', :head
pod 'iRate', '1.11.3'
#pod 'AFNetworking', '2.5.0'
pod 'AFNetworking', :git => 'https://github.com/AFNetworking/AFNetworking.git', :commit => '0e6f9be'
pod 'box-ios-sdk-v2', :git => 'https://github.com/box/box-ios-sdk-v2.git', :commit => '5b9af5c'
pod 'CocoaHTTPServer', '2.3'
pod 'DACircularProgress', :git => 'https://github.com/danielamitay/DACircularProgress.git', :commit => 'ccc7a2e'
pod 'ELCImagePickerController', :git => 'https://github.com/B-Sides/ELCImagePickerController.git', :commit => 'b57e2f3'
pod 'ISO8601DateFormatter', '0.7'
pod 'LTHPasscodeViewController', '3.3.3'
pod 'MBProgressHUD', :git => 'https://github.com/jdg/MBProgressHUD.git', :commit => 'fc1903f'
pod 'objective-zip', '0.8.3'
pod 'OBSlider', '1.1.0'
pod 'PSTCollectionView', '1.2.3'
pod 'SSKeychain', '1.2.2'
pod 'upnpx', :git => 'https://github.com/fkuehne/upnpx.git', :commit => '8e31bd1'
pod 'XMLDictionary', '1.4'
pod 'Google-API-Client/Drive', '1.0.418'
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
#    puts 'Patching SDWebImage to add RAW images decoding (using libRaw)'
#    %x(patch -Np1 < localpods/patches/SDWebImage-add-libRaw-use.patch)
#    puts 'Patching MWPhotoBrowser to enable cookies usage and invalid certificates'
#    %x(patch -Np1 < localpods/patches/MWPhotoBrowser-enable-cookies-and-invalid-certificates.patch)
end
