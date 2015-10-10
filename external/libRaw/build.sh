#!/bin/sh
set -e

SDK=`xcrun --sdk iphoneos --show-sdk-version`

. ../versions

# create curl lib

if [ ! -f LibRaw-${LIBRAW_VERSION}.tar.gz ]
then
wget http://www.libraw.org/data/LibRaw-${LIBRAW_VERSION}.tar.gz
fi

#if [ ! -f LibRaw-demosaic-pack-GPL2-${LIBRAW_VERSION}.tar.gz ]
#then
#wget http://www.libraw.org/data/LibRaw-demosaic-pack-GPL2-${LIBRAW_VERSION}.tar.gz
#fi

#if [ ! -f LibRaw-demosaic-pack-GPL3-${LIBRAW_VERSION}.tar.gz ]
#then
#wget http://www.libraw.org/data/LibRaw-demosaic-pack-GPL3-${LIBRAW_VERSION}.tar.gz
#fi

if [ ! -d LibRaw-${LIBRAW_VERSION} ]
then
    tar xzfv LibRaw-${LIBRAW_VERSION}.tar.gz
fi

#if [ ! -d LibRaw-${LIBRAW_VERSION}/LibRaw-demosaic-pack-GPL2-${LIBRAW_VERSION} ]
#then
#    pushd LibRaw-${LIBRAW_VERSION}
#    tar xzfv ../LibRaw-demosaic-pack-GPL2-${LIBRAW_VERSION}.tar.gz
#    popd
#fi

#if [ ! -d LibRaw-${LIBRAW_VERSION}/LibRaw-demosaic-pack-GPL3-${LIBRAW_VERSION} ]
#then
#    pushd LibRaw-${LIBRAW_VERSION}
#    tar xzfv ../LibRaw-demosaic-pack-GPL3-${LIBRAW_VERSION}.tar.gz
#    popd
#fi


#build armv7
./build-libraw.sh -a armv7 -k $SDK
#build armv7s
./build-libraw.sh -a armv7s -k $SDK
#build arm64
./build-libraw.sh -a arm64 -k $SDK
#build i386
./build-libraw.sh -a i386 -s -k $SDK
#build x86_64
./build-libraw.sh -a x86_64 -s -k $SDK

#create universal library
mkdir -p lib
lipo -create LibRaw-${LIBRAW_VERSION}/install-ios-OS/armv7/lib/libraw.a \
             LibRaw-${LIBRAW_VERSION}/install-ios-OS/armv7s/lib/libraw.a \
             LibRaw-${LIBRAW_VERSION}/install-ios-OS/arm64/lib/libraw.a \
             LibRaw-${LIBRAW_VERSION}/install-ios-Simulator/i386/lib/libraw.a \
             LibRaw-${LIBRAW_VERSION}/install-ios-Simulator/x86_64/lib/libraw.a \
             -output lib/libraw.a
lipo -create LibRaw-${LIBRAW_VERSION}/install-ios-OS/armv7/lib/libraw_r.a \
             LibRaw-${LIBRAW_VERSION}/install-ios-OS/armv7s/lib/libraw_r.a \
             LibRaw-${LIBRAW_VERSION}/install-ios-OS/arm64/lib/libraw_r.a \
             LibRaw-${LIBRAW_VERSION}/install-ios-Simulator/i386/lib/libraw_r.a \
             LibRaw-${LIBRAW_VERSION}/install-ios-Simulator/x86_64/lib/libraw_r.a \
             -output lib/libraw_r.a

#create include folder
cp -r LibRaw-${LIBRAW_VERSION}/install-ios-OS/armv7/include lib/

