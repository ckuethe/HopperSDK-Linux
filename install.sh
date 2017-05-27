#!/bin/bash

set -e

## Variables
SDKVER=4.2.1
GNUSTEP_MAKE_GIT=a964f87bdecab5156ed24f224548680aa2555676 # svn-39575, probably close to what hopper was built with
GNUSTEP_BASE_GIT=03952f1e961931828a3eba62784c02205e8c0a65 # svn-39569, hopper ships libgnustep-base 1.24.9
LIBDISPATCH_REV=e63c3c130c5115b653beca04b7f245e20ba84a08 # hopper ships libdispatch 0.1.3.1

JOBS=$(nproc)
DEST="${HOME}/GNUstep/Library/ApplicationSupport/Hopper"
SDKDIR="${DEST}/HopperSDK-${SDKVER}"
GS_DIR="${DEST}/gnustep-$(arch)"
LAYOUT=fhs

CC=clang
CXX=clang++

## Cleanup
mkdir -p "${DEST}"
echo "Cleaning"
rm -rf sources # comment this out to not remove downloaded sources (saves dowloads) while developing this script
rm -rf "${DEST}/HopperSDK" "${SDKDIR}" "${GS_DIR}"
mkdir -p "${SDKDIR}" "${GS_DIR}" sources

## Download latest Hopper SDK
echo "Downloading sources"
echo "  Hopper SDK"
SDK_ZIP="HopperSDK-${SDKVER}.zip"
test -f sources/$SDK_ZIP || curl -A SDK -L --progress-bar -o sources/$SDK_ZIP "https://d2ap6ypl1xbe4k.cloudfront.net/${SDK_ZIP}"
unzip -qq -d "${SDKDIR}" sources/$SDK_ZIP >/dev/null 2>&1
ln -s "${SDKDIR}" "${DEST}/HopperSDK"

## Download sources
cd sources
echo "  libobjc2..."
D=gnustep-libobjc2
test -d $D || git clone -q https://github.com/gnustep/libobjc2 $D

echo "  gnustep-make..."
D=gnustep-make
test -d $D || git clone -q https://github.com/gnustep/make $D
git -C $D checkout -qf $GNUSTEP_MAKE_GIT

echo "  gnustep-base..."
D=gnustep-base
test -d $D || git clone -q https://github.com/gnustep/base $D
git -C $D checkout -qf $GNUSTEP_BASE_GIT

echo "  libdispatch..."
D=libdispatch
test -d $D || git clone -q https://github.com/nickhutchinson/libdispatch $D
git -C $D checkout -qf $LIBDISPATCH_REV

## Compilation
echo "Compilation"
SRC=$(pwd)
## Compile gnustep-make
echo "  gnustep-make..."
cd gnustep-make
./configure CC=$CC CXX=$CXX --with-layout=$LAYOUT --prefix="${GS_DIR}"
make
make install

cd $SRC
. "${GS_DIR}/share/GNUstep/Makefiles/GNUstep.sh"

## Compile the Objective-C 2 runtime
echo "  libobjc2..."
cd gnustep-libobjc2
rm -rf build ; mkdir build ; cd build
cmake .. -DCMAKE_INSTALL_PREFIX="${GS_DIR}" -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX
make -j$JOBS
make install
cd $SRC

cd gnustep-make
./configure CC=$CC CXX=$CXX --enable-objc-nonfragile-abi --with-layout=$LAYOUT --prefix="${GS_DIR}"
make
make install
cd $SRC

. "${GS_DIR}/share/GNUstep/Makefiles/GNUstep.sh"

## Compile GNUstep base
# On recent Ubuntu (17.04...) you may need to do 'sudo apt install libxml2-dev libgnutls28-dev libxslt1-dev libgcrypt20-dev'
echo "  gnustep-base..."
cd gnustep-base
patch -p0 <../../patches/gnustep-base.patch
./configure CC=$CC CXX=$CXX --prefix="${GS_DIR}"
make -j$JOBS 2>/dev/null
make install
cd $SRC

## Compile libdispatch
echo "  libdispatch..."
cd libdispatch
patch -p1 <../../patches/libdispatch.patch
sed -i"" "s/add_subdirectory(testing)/#add_subdirectory(testing)/" CMakeLists.txt
mkdir build
cd build
cmake .. -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_INSTALL_PREFIX="${GS_DIR}" -DCMAKE_BUILD_TYPE=Release
make
make install
cd $SRC

## Let's test that all is fine by compiling a small Objective-C program
echo "Testing"
cat >test.m<<_EOF
#include <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

@interface A : NSObject
@end

@implementation A
- (id)init {
	if (self = [super init]) {
		NSLog(@"in init");
	}
	return self;
}

- (void)fct {
	NSLog(@"in fct");
	@autoreleasepool {
		NSMutableArray *array = [NSMutableArray array];
		for (int i=0; i<4; i++) {
			[array addObject:[[A alloc] init]];
		}
	}
}

- (void)dealloc {
	NSLog(@"in dealloc");
}
@end


int main(int argc, char **argv) {
	//@autoreleasepool {
	static dispatch_once_t predicate;
	dispatch_once(&predicate, ^ {
			A *a = [[A alloc] init];
			[a fct];
			});
	//}
	return 0;
}
_EOF

clang test.m -o test $(gnustep-config --objc-flags) $(gnustep-config --base-libs) -fobjc-arc -fobjc-nonfragile-abi -O0 -g -ldispatch
./test
echo "GNUstep for Hopper SDK ready."
echo "source '${HOME}/hopper-gnustep.sh' to use it"
ln -fs "${GS_DIR}/share/GNUstep/Makefiles/GNUstep.sh" "${HOME}/hopper-gnustep.sh"
