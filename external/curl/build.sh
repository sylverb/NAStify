#!/bin/sh
set -e

. ../versions

# create curl lib

if [ ! -f curl-${LIBCURL_VERSION}.tar.gz ]
then
wget http://curl.haxx.se/download/curl-${LIBCURL_VERSION}.tar.gz
fi

if [ ! -d curl-${LIBCURL_VERSION} ]
then
tar xzfv curl-${LIBCURL_VERSION}.tar.gz
fi

#build armv7
./build-curl.sh -a armv7
#build armv7s
./build-curl.sh -a armv7s
#build arm64
./build-curl.sh -a arm64
#build i386
./build-curl.sh -a i386 -s
#build x86_64
./build-curl.sh -a x86_64 -s

#create universal libray
mkdir -p lib
lipo -create curl-${LIBCURL_VERSION}/install-ios-OS/armv7/lib/libcurl.a \
             curl-${LIBCURL_VERSION}/install-ios-OS/armv7s/lib/libcurl.a \
             curl-${LIBCURL_VERSION}/install-ios-OS/arm64/lib/libcurl.a \
             curl-${LIBCURL_VERSION}/install-ios-Simulator/i386/lib/libcurl.a \
             curl-${LIBCURL_VERSION}/install-ios-Simulator/x86_64/lib/libcurl.a \
             -output lib/licurl.a

#create include folder
mkdir -p lib/include/curl
cp -r curl-${LIBCURL_VERSION}/install-ios-OS/armv7/include lib/

#Apply patch
patch -Np1 -i curl_arm64_header_fix.patch

#clean
