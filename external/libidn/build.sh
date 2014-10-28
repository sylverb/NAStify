#!/bin/sh
set -e

. ../versions

# create libidn lib

if [ ! -f libidn-${LIBIDN_VERSION}.tar.gz ]
then
wget http://ftp.gnu.org/gnu/libidn/libidn-${LIBIDN_VERSION}.tar.gz
fi

if [ ! -d libidn-${LIBIDN_VERSION} ]
then
tar xzfv libidn-${LIBIDN_VERSION}.tar.gz
fi

#build armv7
./build-libidn.sh -a armv7
#build armv7s
./build-libidn.sh -a armv7s
#build arm64
./build-libidn.sh -a arm64
#build i386
./build-libidn.sh -a i386 -s
#build x86_64
./build-libidn.sh -a x86_64 -s

#create universal libneon
mkdir -p lib
lipo -create libidn-${LIBIDN_VERSION}/install-ios-OS/arm64/lib/libidn.a \
             libidn-${LIBIDN_VERSION}/install-ios-OS/armv7/lib/libidn.a \
             libidn-${LIBIDN_VERSION}/install-ios-OS/armv7s/lib/libidn.a \
             libidn-${LIBIDN_VERSION}/install-ios-Simulator/i386/lib/libidn.a \
             libidn-${LIBIDN_VERSION}/install-ios-Simulator/x86_64/lib/libidn.a \
             -output lib/libidn.a

#create include folder
mkdir -p lib/include
cp -r libidn-${LIBIDN_VERSION}/install-ios-OS/armv7/include lib/

#clean
