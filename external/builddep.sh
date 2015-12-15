#!/bin/sh
PLATFORM=iphoneos
#SDK=`xcrun --sdk iphoneos --show-sdk-version`
SDK=`xcrun --sdk appletvos --show-sdk-version`
VERBOSE=no
CONFIGURATION="Release"
out="/dev/stdout"

TESTEDVLCKITHASH=dbbf6634
TESTEDMEDIALIBRARYKITHASH=e5ca039f

spushd()
{
pushd "$1" 2>&1> /dev/null
}

spopd()
{
popd 2>&1> /dev/null
}

info()
{
     local green="\033[1;32m"
     local normal="\033[0m"
     echo "[${green}info${normal}] $1"
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
git checkout -B iOS-2.7 ${TESTEDVLCKITHASH}
git branch --set-upstream-to=origin/iOS-2.7 iOS-2.7
cd ..
else
cd VLCKit
git pull --rebase
git reset --hard ${TESTEDVLCKITHASH}
cd ..
fi

info "Building VLCKit"

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
./buildMobileVLCKit.sh -t -k "${SDK}"
spopd

#spushd MediaLibraryKit
#rm -f External/MobileVLCKit
#ln -sf ${framework_build} External/MobileVLCKit
#buildxcodeproj MediaLibraryKit
#spopd

