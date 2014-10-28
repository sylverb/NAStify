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
fi

#build x86_64
./build-neon.sh -s -a x86_64
#build arm64
./build-neon.sh -a arm64
#build armv7s
./build-neon.sh -a armv7s
#build armv7
./build-neon.sh -a armv7
#build i386
./build-neon.sh -s -a i386

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
