#!/bin/sh
set -e

. ../versions

PLATFORM=OS
VERBOSE=no
DEBUG=no
SDK_VERSION=`xcrun --sdk iphoneos --show-sdk-version`
SDK_MIN=7.0
SIXTYFOURBIT_SDK_MIN=7.0
ARCH=armv7
SCARY=yes
TVOS=no
OSSTYLE=iPhone
OSVERSIONMINCFLAG=miphoneos-version-min
OSVERSIONMINLDFLAG=ios_version_min

CORE_COUNT=`sysctl -n machdep.cpu.core_count`
let MAKE_JOBS=$CORE_COUNT+1

usage()
{
cat << EOF
usage: $0 [-s] [-k sdk]

OPTIONS
   -k <sdk version>      Specify which sdk to use ('xcodebuild -showsdks', current: ${SDK_VERSION})
   -s            Build for simulator
   -t            Build for tvOS
   -a <arch>     Specify which arch to use (current: ${ARCH})
   -d            Enable debug
   -v            Enable verbose command-line output
EOF
}

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
    local blue="\033[1;34m"
    local normal="\033[0m"
    echo "[${blue}info${normal}] $1"
}

while getopts "hvdstk:a:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             VERBOSE=yes
             ;;
         s)
             PLATFORM=Simulator
             ;;
         d)
             DEBUG=yes
             ;;
         k)
             SDK_VERSION=$OPTARG
             ;;
         a)
             ARCH=$OPTARG
             ;;
         t)
             TVOS=yes
             SDK_VERSION=`xcrun --sdk appletvos --show-sdk-version`
             OSVERSIONMINCFLAG=mtvos-version-min
             OSVERSIONMINLDFLAG=tvos_version_min
             SIXTYFOURBIT_SDK_MIN=9.0
             ;;
         ?)
             usage
             exit 1
             ;;
     esac
done
shift $(($OPTIND - 1))

if [ "x$1" != "x" ]; then
    usage
    exit 1
fi

out="/dev/null"
if [ "$VERBOSE" = "yes" ]; then
   out="/dev/stdout"
fi

TARGET="${ARCH}-apple-darwin11"

# apple doesn't call AArch64 that way, but arm64 (a contrario to all libraries)
# so we need to translate it..

if [ "$ARCH" = "aarch64" ]; then
   ACTUAL_ARCH="arm64"
else
   ACTUAL_ARCH="$ARCH"
fi

if [ "$DEBUG" = "yes" ]; then
   OPTIM="-O0 -g"
else
   OPTIM="-O3 -g"
fi

if [ "$TVOS" = "yes" ]; then
   OSSTYLE=AppleTV
   export BUILDFORTVOS="yes"
fi
export BUILDFORIOS="yes"

info "Building neon for '${OSSTYLE}'"
info "Using ${ARCH} with SDK version ${SDK_VERSION}"

THIS_SCRIPT_PATH=`pwd`/$0

spushd `dirname ${THIS_SCRIPT_PATH}`/neon-${LIBNEON_VERSION}
NEONROOT=`pwd` # Let's make sure NEONROOT is an absolute path
spopd

if test -z "$SDKROOT"
then
    SDKROOT=`xcode-select -print-path`/Platforms/${OSSTYLE}${PLATFORM}.platform/Developer/SDKs/${OSSTYLE}${PLATFORM}${SDK_VERSION}.sdk
    echo "SDKROOT not specified, assuming $SDKROOT"
fi

if [ ! -d "${SDKROOT}" ]
then
    echo "*** ${SDKROOT} does not exist, please install required SDK, or set SDKROOT manually. ***"
    exit 1
fi

BUILDDIR="${NEONROOT}/build-ios-${OSSTYLE}${PLATFORM}/${ACTUAL_ARCH}"
PREFIX="${NEONROOT}/install-ios-${OSSTYLE}${PLATFORM}/${ACTUAL_ARCH}"

# The contrib will read the following
export AR="xcrun ar"

export RANLIB="xcrun ranlib"
export CC="xcrun clang"
export OBJC="xcrun clang"
export CXX="xcrun clang++"
export LD="xcrun ld"
export STRIP="xcrun strip"


export PLATFORM=$PLATFORM
export SDK_VERSION=$SDK_VERSION

CFLAGS="-isysroot ${SDKROOT} -arch ${ACTUAL_ARCH} ${OPTIM}"

if [ "$PLATFORM" = "OS" ]; then
if [ "$ARCH" != "aarch64" ]; then
   CFLAGS+=" -mcpu=cortex-a8 -${OSVERSIONMINCFLAG}=${SDK_MIN}"
else
   CFLAGS+=" -${OSVERSIONMINCFLAG}=${SIXTYFOURBIT_SDK_MIN}"
fi
else
   CFLAGS+=" -${OSVERSIONMINCFLAG}=${SIXTYFOURBIT_SDK_MIN}"
fi

# Enable bitcode
CFLAGS+=" -fembed-bitcode"

export CFLAGS="${CFLAGS} -Wno-error=implicit-function-declaration"
export CXXFLAGS="${CFLAGS}"
export CPPFLAGS="${CFLAGS}"

export CPP="xcrun cc -E"
export CXXCPP="xcrun c++ -E"

if [ "$PLATFORM" = "Simulator" ]; then
   # Use the new ABI on simulator, else we can't build
   export OBJCFLAGS="-fobjc-abi-version=2 -fobjc-legacy-dispatch ${OBJCFLAGS}"
fi

export LDFLAGS="-isysroot ${SDKROOT} -L${SDKROOT}/usr/lib -arch ${ACTUAL_ARCH}"

if [ "$PLATFORM" = "OS" ]; then
   EXTRA_CFLAGS="-arch ${ACTUAL_ARCH}"
   EXTRA_LDFLAGS="-arch ${ACTUAL_ARCH}"
if [ "$ARCH" != "aarch64" ]; then
   EXTRA_CFLAGS+=" -mcpu=cortex-a8"
   EXTRA_CFLAGS+=" -${OSVERSIONMINCFLAG}=${SDK_MIN}"
   EXTRA_LDFLAGS+=" -Wl,-${OSVERSIONMINLDFLAG},${SDK_MIN}"
export LDFLAGS="${LDFLAGS} -Wl,-${OSVERSIONMINLDFLAG},${SDK_MIN}"
else
   EXTRA_CFLAGS+=" -${OSVERSIONMINCFLAG}=${SIXTYFOURBIT_SDK_MIN}"
   EXTRA_LDFLAGS+=" -Wl,-${OSVERSIONMINLDFLAG},${SIXTYFOURBIT_SDK_MIN}"
export LDFLAGS="${LDFLAGS} -Wl,-${OSVERSIONMINLDFLAG},${SIXTYFOURBIT_SDK_MIN}"
fi
else
   EXTRA_CFLAGS="-arch ${ARCH}"
   EXTRA_CFLAGS+=" -${OSVERSIONMINCFLAG}=${SIXTYFOURBIT_SDK_MIN}"
   EXTRA_LDFLAGS=" -Wl,-${OSVERSIONMINLDFLAG},${SIXTYFOURBIT_SDK_MIN}"
   export LDFLAGS="${LDFLAGS} -v -Wl,-${OSVERSIONMINLDFLAG},${SIXTYFOURBIT_SDK_MIN}"
fi


info "LD FLAGS SELECTED = '${LDFLAGS}'"

mkdir -p ${BUILDDIR}
spushd ${BUILDDIR}

export MACOSX_DEPLOYMENT_TARGET="10.4"

info ">> --prefix=${PREFIX} --host=${TARGET}"

${NEONROOT}/configure \
    --prefix="${PREFIX}" \
    --host="${TARGET}" \
    --enable-debug \
    --enable-static \
    --disable-shared \
    --with-ssl=openssl \
    --enable-threadsafe-ssl=posix \
    --with-libs="${NEONROOT}/../../openssl/bin/openssl-${OPENSSL_VERSION}-${OSSTYLE}-${ACTUAL_ARCH}" \
    --with-libxml2 > ${out} # MMX and SSE support requires llvm which is broken on Simulator

CORE_COUNT=`sysctl -n machdep.cpu.core_count`
let MAKE_JOBS=$CORE_COUNT+1

make -j$MAKE_JOBS > ${out}

make install > ${out}
popd

