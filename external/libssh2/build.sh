#!/bin/sh
set -e

SDK=`xcrun --sdk iphoneos --show-sdk-version`

. ../versions

# create curl lib

if [ ! -f libssh2-${LIBSSH2_VERSION}.tar.gz ]
then
wget http://www.libssh2.org/download/libssh2-${LIBSSH2_VERSION}.tar.gz
fi

if [ ! -d libssh2-${LIBSSH2_VERSION} ]
then
tar xzfv libssh2-${LIBSSH2_VERSION}.tar.gz
fi

#build armv7
./build-libssh2.sh -a armv7 -k $SDK
#build armv7s
./build-libssh2.sh -a armv7s -k $SDK
#build arm64
./build-libssh2.sh -a arm64 -k $SDK
#build i386
./build-libssh2.sh -a i386 -s -k $SDK
#build x86_64
./build-libssh2.sh -a x86_64 -s -k $SDK

#create universal libray
mkdir -p lib
lipo -create libssh2-${LIBSSH2_VERSION}/install-ios-OS/armv7/lib/libssh2.a \
             libssh2-${LIBSSH2_VERSION}/install-ios-OS/armv7s/lib/libssh2.a \
             libssh2-${LIBSSH2_VERSION}/install-ios-OS/arm64/lib/libssh2.a \
             libssh2-${LIBSSH2_VERSION}/install-ios-Simulator/i386/lib/libssh2.a \
             libssh2-${LIBSSH2_VERSION}/install-ios-Simulator/x86_64/lib/libssh2.a \
             -output lib/libssh2.a

#create include folder
cp -r libssh2-${LIBSSH2_VERSION}/install-ios-OS/armv7/include lib/

#clean
