#!/bin/sh
PLATFORM=iphoneos
SDK=`xcrun --sdk iphoneos --show-sdk-version`
SDK_MIN=6.1
VERBOSE=no
CONFIGURATION="Release"
out="/dev/stdout"

info()
{
     local green="\033[1;32m"
     local normal="\033[0m"
     echo "[${green}info${normal}] $1"
}

buildxcodeproj()
{
    local target="$2"
    if [ "x$target" = "x" ]; then
        target="$1"
    fi

    info "Building $1 ($target, ${CONFIGURATION})"

    xcodebuild -project "$1.xcodeproj" \
               -target "$target" \
               -sdk $PLATFORM$SDK \
               -configuration ${CONFIGURATION} \
               IPHONEOS_DEPLOYMENT_TARGET=${SDK_MIN} > ${out}
}

#pushd openssl
#./build.sh
#popd
#pushd libssh2
#./build.sh
#popd
#pushd libidn
#./build.sh
#popd
#pushd curl
#./build.sh
#popd
#pushd neon
#./build.sh
#popd
#pushd libRaw
#./build.sh
#popd
#pushd samba
#rake
#popd
#git clone git://git.videolan.org/vlc-bindings/VLCKit.git
#pushd VLCKit
#./buildMobileVLCKit.sh
#popd
git clone git://git.videolan.org/MediaLibraryKit.git
pushd MediaLibraryKit
ln -s ../VLCKit/MobileVLCKit MobileVLCKit
buildxcodeproj MediaLibraryKit
popd
