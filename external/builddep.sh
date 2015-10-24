#!/bin/sh
PLATFORM=iphoneos
SDK=`xcrun --sdk iphoneos --show-sdk-version`
SDK_MIN=7.0
VERBOSE=no
CONFIGURATION="Release"
out="/dev/stdout"

TESTEDVLCKITHASH=60f6062d
TESTEDMEDIALIBRARYKITHASH=1a308536

info()
{
     local green="\033[1;32m"
     local normal="\033[0m"
     echo "[${green}info${normal}] $1"
}

buildxcworkspace()
{
    local target="$2"
    if [ "x$target" = "x" ]; then
        target="$1"
    fi

    info "Building the workspace $1 ($target, ${CONFIGURATION})"

    local architectures=""
    if [ "$PLATFORM" = "iphonesimulator" ]; then
        architectures="i386 x86_64"
    else
        architectures="armv7 armv7s arm64"
    fi

    xcodebuild -workspace "$1.xcworkspace" \
    -scheme "Pods-vlc-ios" \
    -sdk $PLATFORM$SDK \
    -configuration ${CONFIGURATION} \
    ARCHS="${architectures}" \
    IPHONEOS_DEPLOYMENT_TARGET=${SDK_MIN} > ${out}
}

pushd openssl
./build.sh
popd
pushd libssh2
./build.sh
popd
pushd libidn
./build.sh
popd
pushd curl
./build.sh
popd
pushd cryptopp
./build.sh
popd
pushd cares
./build.sh
popd
pushd neon
./build.sh
popd
pushd libRaw
./build.sh
popd
pushd samba
rake
popd



# Setup paths
# Get root dir
spushd .
nastify_root_dir=`pwd`
spopd

if [ "$PLATFORM" = "iphonesimulator" ]; then
xcbuilddir="build/${CONFIGURATION}-iphonesimulator"
else
xcbuilddir="build/${CONFIGURATION}-iphoneos"
fi
framework_build="${nastify_root_dir}/external/VLCKit/${xcbuilddir}"
mlkit_build="${nastify_root_dir}/external/MediaLibraryKit/${xcbuilddir}"

# VLC get source
if ! [ -e MediaLibraryKit ]; then
git clone http://code.videolan.org/videolan/MediaLibraryKit.git
cd MediaLibraryKit
git checkout -B 2.5.x ${TESTEDMEDIALIBRARYKITHASH}
git branch --set-upstream-to=origin/2.5.x 2.5.x
cd ..
else
cd MediaLibraryKit
git pull --rebase
git reset --hard ${TESTEDMEDIALIBRARYKITHASH}
cd ..
fi
if ! [ -e VLCKit ]; then
git clone http://code.videolan.org/videolan/VLCKit.git
cd VLCKit
git checkout -B 2.2.x ${TESTEDVLCKITHASH}
git branch --set-upstream-to=origin/2.2.x 2.2.x
cd ..
else
cd VLCKit
git pull --rebase
git reset --hard ${TESTEDVLCKITHASH}
cd ..
fi

spushd VLCKit
echo `pwd`
args=""
if [ "$VERBOSE" = "yes" ]; then
args="${args} -v"
fi
if [ "$PLATFORM" = "iphonesimulator" ]; then
args="${args} -s"
fi
if [ "$NONETWORK" = "yes" ]; then
args="${args} -n"
fi
if [ "$SKIPLIBVLCCOMPILATION" = "yes" ]; then
args="${args} -l"
fi
./buildMobileVLCKit.sh ${args} -k "${SDK}"
buildxcodeproj MobileVLCKit "Aggregate static plugins"
buildxcodeproj MobileVLCKit "MobileVLCKit"
spopd

spushd MediaLibraryKit
rm -f External/MobileVLCKit
ln -sf ${framework_build} External/MobileVLCKit
buildxcodeproj MediaLibraryKit
spopd

