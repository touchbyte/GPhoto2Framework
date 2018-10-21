export DEVROOT=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain
DFT_DIST_DIR=${HOME}/Desktop/gphoto-ios-dist
DIST_DIR=${DIST_DIR:-$DFT_DIST_DIR}



function build_for_arch() {
  ARCH=$1
  HOST=$2
  SYSROOT=$3
  PREFIX=$4
  IPHONEOS_DEPLOYMENT_TARGET="8.0"
  make clean
  export PATH="${DEVROOT}/usr/bin/:${PATH}"
  export CFLAGS="-I/opt/iphonesimulator-12.0/x86_64/include -arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SYSROOT} -miphoneos-version-min=${IPHONEOS_DEPLOYMENT_TARGET} -fembed-bitcode"
  export LDFLAGS="-L/opt/iphonesimulator-12.0/x86_64/lib -arch ${ARCH} -isysroot ${SYSROOT}"
  ./configure --without-usb --without-libusb_1_0 --without-libusb --disable-serial --disable-disk --prefix=/opt/iphonesimulator-12.0/x86_64 --with-gdlib=no --host="${HOST}" --prefix=${PREFIX} && make -j8 CPPFLAGS=-D_DARWIN_C_SOURCE && make install
}

TMP_DIR=/tmp/build_libgphoto_$$

build_for_arch x86_64 x86_64-apple-darwin /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk ${TMP_DIR}/x86_64 || exit 5
