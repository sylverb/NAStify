#!/bin/bash

. ../versions

THIS_SCRIPT_PATH=`pwd`
DESTFOLDER=${THIS_SCRIPT_PATH}/bin

mkdir -p ${DESTFOLDER}

detectedSSLVersion=""
# Verify that OpenSSL has been downloaded
if [ -f openssl*z ]; then
	for ssltgz in openssl*z
	do
		detectedSSLVersion=`echo $ssltgz | sed 's/openssl-\(.*\).tar.gz/\1/'`
	done
else
	echo "OpenSSL has not been downloaded, getting it from http://openssl.org/source/"
	wget http://openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
	detectedSSLVersion=${OPENSSL_VERSION}
fi

echo "Compiling OpenSSL ${detectedSSLVersion}..."

DEVELOPER="/Applications/Xcode.app/Contents/Developer"

SDK_VERSION="8.1"
MIN_VERSION="7.0"

IPHONEOS_PLATFORM=`xcode-select -print-path`/Platforms/iPhoneOS.platform
IPHONEOS_SDK="${IPHONEOS_PLATFORM}/Developer/SDKs/iPhoneOS${SDK_VERSION}.sdk"
IPHONEOS_GCC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"

IPHONESIMULATOR_PLATFORM=`xcode-select -print-path`/Platforms/iPhoneSimulator.platform
IPHONESIMULATOR_SDK="${IPHONESIMULATOR_PLATFORM}/Developer/SDKs/iPhoneSimulator${SDK_VERSION}.sdk"
IPHONESIMULATOR_GCC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"




# Make sure things actually exist

if [ ! -d "$IPHONEOS_PLATFORM" ]; then
  echo "Cannot find $IPHONEOS_PLATFORM"
  exit 1
fi

if [ ! -d "$IPHONEOS_SDK" ]; then
  echo "Cannot find $IPHONEOS_SDK"
  exit 1
fi

if [ ! -x "$IPHONEOS_GCC" ]; then
  echo "Cannot find $IPHONEOS_GCC"
  exit 1
fi

if [ ! -d "$IPHONESIMULATOR_PLATFORM" ]; then
  echo "Cannot find $IPHONESIMULATOR_PLATFORM"
  exit 1
fi

if [ ! -d "$IPHONESIMULATOR_SDK" ]; then
  echo "Cannot find $IPHONESIMULATOR_SDK"
  exit 1
fi

if [ ! -x "$IPHONESIMULATOR_GCC" ]; then
  echo "Cannot find $IPHONESIMULATOR_GCC"
  exit 1
fi

# Clean up whatever was left from our previous build

rm -rf include lib bin

mkdir bin

build()
{
   TARGET=$1
   ARCH=$2
   GCC=$3
   SDK=$4
   EXTRA=$5
   echo "Building arch $ARCH"
   rm -rf "openssl-${detectedSSLVersion}"
   tar xfz "openssl-${detectedSSLVersion}.tar.gz"
   pushd .
   cd "openssl-${detectedSSLVersion}"
   ./Configure ${TARGET} --openssldir="${DESTFOLDER}/openssl-${detectedSSLVersion}-${ARCH}" ${EXTRA} &> "${DESTFOLDER}/openssl-${detectedSSLVersion}-${ARCH}.log"
   perl -i -pe 's|static volatile sig_atomic_t intr_signal|static volatile int intr_signal|' crypto/ui/ui_openssl.c
   perl -i -pe "s|^CC= gcc|CC= ${GCC} -arch ${ARCH} -miphoneos-version-min=${MIN_VERSION}|g" Makefile
   perl -i -pe "s|^CFLAG= (.*)|CFLAG= -isysroot ${SDK} \$1|g" Makefile
   make &>  "${DESTFOLDER}/openssl-${OPENSSL_VERSION}-${ARCH}.build-log"
   make install &> "${DESTFOLDER}/openssl-${detectedSSLVersion}-${ARCH}.install-log"
   popd
   rm -rf "openssl-${detectedSSLVersion}"
}

build "BSD-generic32" "armv7" "${IPHONEOS_GCC}" "${IPHONEOS_SDK}" ""
build "BSD-generic32" "armv7s" "${IPHONEOS_GCC}" "${IPHONEOS_SDK}" ""
build "BSD-generic64" "arm64" "${IPHONEOS_GCC}" "${IPHONEOS_SDK}" ""
build "BSD-generic32" "i386" "${IPHONESIMULATOR_GCC}" "${IPHONESIMULATOR_SDK}" ""
build "BSD-generic64" "x86_64" "${IPHONESIMULATOR_GCC}" "${IPHONESIMULATOR_SDK}" "-DOPENSSL_NO_ASM"

#

mkdir -p lib/include
cp -r ${DESTFOLDER}/openssl-${detectedSSLVersion}-i386/include/openssl lib/include/

lipo \
	"${DESTFOLDER}/openssl-${detectedSSLVersion}-armv7/lib/libcrypto.a" \
	"${DESTFOLDER}/openssl-${detectedSSLVersion}-armv7s/lib/libcrypto.a" \
	"${DESTFOLDER}/openssl-${detectedSSLVersion}-arm64/lib/libcrypto.a" \
	"${DESTFOLDER}/openssl-${detectedSSLVersion}-i386/lib/libcrypto.a" \
	"${DESTFOLDER}/openssl-${detectedSSLVersion}-x86_64/lib/libcrypto.a" \
	-create -output lib/libcrypto.a
lipo \
	"${DESTFOLDER}/openssl-${detectedSSLVersion}-armv7/lib/libssl.a" \
	"${DESTFOLDER}/openssl-${detectedSSLVersion}-armv7s/lib/libssl.a" \
	"${DESTFOLDER}/openssl-${detectedSSLVersion}-arm64/lib/libssl.a" \
	"${DESTFOLDER}/openssl-${detectedSSLVersion}-i386/lib/libssl.a" \
	"${DESTFOLDER}/openssl-${detectedSSLVersion}-x86_64/lib/libssl.a" \
	-create -output lib/libssl.a
