#!/bin/sh
set -e

SDK=`xcrun --sdk iphoneos --show-sdk-version`

. ../versions

# create curl lib

if [ ! -f neon-${LIBNEON_VERSION}.tar.gz ]
then
wget http://www.webdav.org/neon/neon-${LIBNEON_VERSION}.tar.gz
fi

if [ ! -d neon-${LIBNEON_VERSION} ]
then
tar xzfv neon-${LIBNEON_VERSION}.tar.gz
cd neon-${LIBNEON_VERSION}
patch -Np1 -i ../neon-allow-bitcode-compilation.patch
cd ..
fi

#build x86_64
./build-neon.sh -s -a x86_64 -k $SDK
#build arm64
./build-neon.sh -a arm64 -k $SDK
#build armv7s
./build-neon.sh -a armv7s -k $SDK
#build armv7
./build-neon.sh -a armv7 -k $SDK
#build i386
./build-neon.sh -s -a i386 -k $SDK

#create universal libneon
mkdir -p lib
lipo -create neon-${LIBNEON_VERSION}/install-ios-OS/arm64/lib/libneon.a \
             neon-${LIBNEON_VERSION}/install-ios-OS/armv7/lib/libneon.a \
             neon-${LIBNEON_VERSION}/install-ios-OS/armv7s/lib/libneon.a \
             neon-${LIBNEON_VERSION}/install-ios-Simulator/i386/lib/libneon.a \
             neon-${LIBNEON_VERSION}/install-ios-Simulator/x86_64/lib/libneon.a \
             -output lib/libneon.a

#create include folder
mkdir -p lib/include
cp -r neon-${LIBNEON_VERSION}/install-ios-OS/armv7/include/neon lib/include/

#clean
