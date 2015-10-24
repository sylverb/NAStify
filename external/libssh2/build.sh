#!/bin/sh
set -e

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
./build-libssh2.sh -a armv7
#build armv7s
./build-libssh2.sh -a armv7s
#build arm64
./build-libssh2.sh -a aarch64
#build i386
./build-libssh2.sh -a i386 -s
#build x86_64
./build-libssh2.sh -a x86_64 -s

#build arm64 tvOS
./build-libssh2.sh -a aarch64 -t
#build x86_64 tvOS
./build-libssh2.sh -a x86_64 -s -t

#create universal libray
mkdir -p lib
lipo -create libssh2-${LIBSSH2_VERSION}/install-ios-iPhoneOS/armv7/lib/libssh2.a \
             libssh2-${LIBSSH2_VERSION}/install-ios-iPhoneOS/armv7s/lib/libssh2.a \
             libssh2-${LIBSSH2_VERSION}/install-ios-iPhoneOS/arm64/lib/libssh2.a \
             libssh2-${LIBSSH2_VERSION}/install-ios-iPhoneSimulator/i386/lib/libssh2.a \
             libssh2-${LIBSSH2_VERSION}/install-ios-iPhoneSimulator/x86_64/lib/libssh2.a \
             -output lib/libssh2.a

lipo -create libssh2-${LIBSSH2_VERSION}/install-ios-AppleTVOS/arm64/lib/libssh2.a \
             libssh2-${LIBSSH2_VERSION}/install-ios-AppleTVSimulator/x86_64/lib/libssh2.a \
             -output lib/tvos-libssh2.a

#create include folder
cp -r libssh2-${LIBSSH2_VERSION}/install-ios-iPhoneOS/armv7/include lib/

#clean
