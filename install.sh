#!/bin/bash

set -e

## Variables
SUFFIX=$(uname)-$(arch)

SDKVER=4.1.5
GNUSTEP_REV=37819
GNUSTEP_BASE_GIT=3c4ff69d696e2b5d4afacf70352b5d483b18997b # close to svn-37819
GNUSTEP_MAKE_GIT=0b7a76a45e9f6d7dc4d982c226fff111465d1272 # close to svn-37819
LIBDISPATCH_REV=700a514955d6c86b29439c80f3bc0b69405b43f0

JOBS=$(nproc)
DEST=$(pwd)/gnustep-$SUFFIX
LAYOUT=fhs

CC=clang
CXX=clang++

## Cleanup
echo "Cleaning"
rm -rf "$DEST"
rm -rf sources ; mkdir sources

## Download latest Hopper SDK
echo "Downloading Hopper SDK"
curl -A SDK -L --progress-bar -o HopperSDK-${SDKVER}.zip "https://d2ap6ypl1xbe4k.cloudfront.net/HopperSDK-${SDKVER}.zip"
rm -rf HopperSDK ; mkdir HopperSDK
cd HopperSDK ; unzip ../HopperSDK-${SDKVER}.zip >/dev/null && rm ../HopperSDK-${SDKVER}.zip ; cd ..

## Download sources
echo "Downloading sources"
cd sources
echo "  libobjc2..."
git clone https://github.com/gnustep/libobjc2 gnustep-libobjc2 >/dev/null
echo "  gnustep-make..."
git clone https://github.com/gnustep/make gnustep-make >/dev/null
git -C gnustep-make checkout -q $GNUSTEP_MAKE_GIT
echo "  gnustep-base..."
git clone https://github.com/gnustep/base gnustep-base >/dev/null
git -C gnustep-base checkout -q $GNUSTEP_BASE_GIT
echo "  libdispatch..."
git clone https://github.com/nickhutchinson/libdispatch.git >/dev/null
git -C libdispatch checkout -q $LIBDISPATCH_REV

## Compilation
echo "Compilation"

## Compile gnustep-make
echo "  gnustep-make..."
cd gnustep-make
./configure CC=$CC CXX=$CXX --with-layout=$LAYOUT --prefix="$DEST"
make
make install
cd ..

. "$DEST/share/GNUstep/Makefiles/GNUstep.sh"

## Compile the Objective-C 2 runtime
echo "  libobjc2..."
cd gnustep-libobjc2
rm -rf build ; mkdir build ; cd build
cmake .. -DCMAKE_INSTALL_PREFIX="$DEST" -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX
make -j$JOBS
make install
cd ../../

cd gnustep-make
./configure CC=$CC CXX=$CXX --enable-objc-nonfragile-abi --with-layout=$LAYOUT --prefix="$DEST"
make
make install
cd ..

. "$DEST/share/GNUstep/Makefiles/GNUstep.sh"

## Compile GNUstep base
# On recent Ubuntu (17.04...) you may need to do 'sudo apt install libxml2-dev libgnutls28-dev libxslt1-dev libgcrypt20-dev'
echo "  gnustep-base..."
cd gnustep-base
patch -p0 <../../patches/gnustep-base.patch
./configure CC=$CC CXX=$CXX --prefix="$DEST" # --disable-xslt --disable-tls
make -j$JOBS 2>/dev/null
make install
cd ..

## Compile libdispatch
echo "  libdispatch..."
cd libdispatch
patch -p1 <../../patches/libdispatch.patch || exit 1
sed -i"" "s/add_subdirectory(testing)/#add_subdirectory(testing)/" CMakeLists.txt
mkdir build
cd build
cmake .. -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_INSTALL_PREFIX="$DEST" -DCMAKE_BUILD_TYPE=Release
make
make install
cd ../..

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

clang test.m -o test $(gnustep-config --objc-flags) $(gnustep-config --base-libs) -fobjc-arc -fobjc-nonfragile-abi -O0 -g -ldispatch && ./test && echo "ALL DONE"

