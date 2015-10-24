#!/bin/sh
set -e

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

#build armv7
./build-neon.sh -a armv7
#build armv7s
./build-neon.sh -a armv7s
#build arm64
./build-neon.sh -a aarch64
#build i386
./build-neon.sh -s -a i386
#build x86_64
./build-neon.sh -s -a x86_64

#build tvOS aarch64
./build-neon.sh -a aarch64 -t
#build tvOS x86_64
./build-neon.sh -a x86_64 -t -s

#create universal libneon
mkdir -p lib
lipo -create neon-${LIBNEON_VERSION}/install-ios-iPhoneOS/armv7/lib/libneon.a \
             neon-${LIBNEON_VERSION}/install-ios-iPhoneOS/armv7s/lib/libneon.a \
             neon-${LIBNEON_VERSION}/install-ios-iPhoneOS/arm64/lib/libneon.a \
             neon-${LIBNEON_VERSION}/install-ios-iPhoneSimulator/i386/lib/libneon.a \
             neon-${LIBNEON_VERSION}/install-ios-iPhoneSimulator/x86_64/lib/libneon.a \
             -output lib/libneon.a

lipo -create neon-${LIBNEON_VERSION}/install-ios-AppleTVOS/arm64/lib/libneon.a \
             neon-${LIBNEON_VERSION}/install-ios-AppleTVSimulator/x86_64/lib/libneon.a \
             -output lib/tvos-libneon.a

#create include folder
mkdir -p lib/include
cp -r neon-${LIBNEON_VERSION}/install-ios-iPhoneOS/armv7/include/neon lib/include/

#clean
