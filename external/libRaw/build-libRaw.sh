#!/bin/sh
set -e

. ../versions

PLATFORM=OS
VERBOSE=no
SDK_VERSION=8.3
SDK_MIN=7.0
ARCH=armv7

usage()
{
cat << EOF
usage: $0 [-s] [-k sdk]

OPTIONS
   -k <sdk version>      Specify which sdk to use ('xcodebuild -showsdks', current: ${SDK_VERSION})
   -s            Build for simulator
   -a <arch>     Specify which arch to use (current: ${ARCH})
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

while getopts "hvsk:a:" OPTION
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
         k)
             SDK_VERSION=$OPTARG
             ;;
         a)
             ARCH=$OPTARG
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

info "Building libRaw for iOS"

if [ "$PLATFORM" = "Simulator" ]; then
    TARGET="${ARCH}-apple-darwin11"
    OPTIM="-O3 -g"
else
    TARGET="arm-apple-darwin11"
    OPTIM="-O3 -g"
fi

info "Using ${ARCH} with SDK version ${SDK_VERSION}"

THIS_SCRIPT_PATH=`pwd`/$0

spushd `dirname ${THIS_SCRIPT_PATH}`/LibRaw-${LIBRAW_VERSION}
RAWROOT=`pwd` # Let's make sure RAWROOT is an absolute path
spopd

if test -z "$SDKROOT"
then
    SDKROOT=`xcode-select -print-path`/Platforms/iPhone${PLATFORM}.platform/Developer/SDKs/iPhone${PLATFORM}${SDK_VERSION}.sdk
    echo "SDKROOT not specified, assuming $SDKROOT"
fi

if [ ! -d "${SDKROOT}" ]
then
    echo "*** ${SDKROOT} does not exist, please install required SDK, or set SDKROOT manually. ***"
    exit 1
fi

BUILDDIR="${RAWROOT}/build-ios-${PLATFORM}/${ARCH}"

PREFIX="${RAWROOT}/install-ios-${PLATFORM}/${ARCH}"

export PATH="${RAWROOT}/extras/tools/build/bin:${RAWROOT}/contrib/${TARGET}/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin"

# contains gas-processor.pl
export PATH=$PATH:${RAWROOT}/extras/package/ios/resources

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

if [ "$PLATFORM" = "OS" ]; then
export CFLAGS="-isysroot ${SDKROOT} -arch ${ARCH} -miphoneos-version-min=${SDK_MIN} ${OPTIM}"
if [ "$ARCH" != "arm64" ]; then
export CFLAGS="${CFLAGS} -mcpu=cortex-a8"
fi
else
export CFLAGS="-isysroot ${SDKROOT} -arch ${ARCH} -miphoneos-version-min=${SDK_MIN} ${OPTIM}"
fi
export CFLAGS="${CFLAGS} -Wno-error=implicit-function-declaration"
export CPPFLAGS="${CFLAGS}"
export CXXFLAGS="${CFLAGS}"
export OBJCFLAGS="${CFLAGS}"

export CPP="xcrun cc -E"
export CXXCPP="xcrun c++ -E"

export BUILDFORIOS="yes"

if [ "$PLATFORM" = "Simulator" ]; then
    # Use the new ABI on simulator, else we can't build
    export OBJCFLAGS="-fobjc-abi-version=2 -fobjc-legacy-dispatch ${OBJCFLAGS}"
fi

export LDFLAGS="-L${SDKROOT}/usr/lib -arch ${ARCH} -isysroot ${SDKROOT} -miphoneos-version-min=${SDK_MIN}"

if [ "$PLATFORM" = "OS" ]; then
    EXTRA_CFLAGS="-arch ${ARCH}"
if [ "$ARCH" != "arm64" ]; then
    EXTRA_CFLAGS+=" -mcpu=cortex-a8"
fi
    EXTRA_LDFLAGS="-arch ${ARCH}"
else
    EXTRA_CFLAGS="-arch ${ARCH}"
    EXTRA_LDFLAGS="-arch ${ARCH}"
fi

EXTRA_CFLAGS+=" -miphoneos-version-min=${SDK_MIN}"
EXTRA_LDFLAGS+=" -miphoneos-version-min=${SDK_MIN}"

info "LD FLAGS SELECTED = '${LDFLAGS}'"

mkdir -p ${BUILDDIR}
spushd ${BUILDDIR}

info ">> --prefix=${PREFIX} --host=${TARGET}"

${RAWROOT}/configure \
    --prefix="${PREFIX}" \
    --host="${TARGET}" \
    --enable-static \
    --disable-shared > ${out}

CORE_COUNT=`sysctl -n machdep.cpu.core_count`
let MAKE_JOBS=$CORE_COUNT+1

#info "Building libRaw"
make -j$MAKE_JOBS > ${out}

make install > ${out}

popd

