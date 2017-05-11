#!/bin/bash

## Variables
SUFFIX=$(uname)-$(arch)

GNUSTEP_REV=37819
LIBDISPATCH_REV=700a514955d6c86b29439c80f3bc0b69405b43f0

JOBS=4
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
curl -A SDK -L -o HopperSDK.zip "http://www.hopperapp.com/HopperWeb/download_last_v3.php?platform=SDK"
rm -rf HopperSDK ; mkdir HopperSDK
cd HopperSDK ; unzip ../HopperSDK.zip >/dev/null && rm ../HopperSDK.zip ; cd ..

## Download sources
echo "Downloading sources"
cd sources
echo "  libobjc2..."
svn co -r $GNUSTEP_REV http://svn.gna.org/svn/gnustep/libs/libobjc2/trunk/ gnustep-libobjc2 >/dev/null  || exit 1
echo "  gnustep-make..."
svn co -r $GNUSTEP_REV http://svn.gna.org/svn/gnustep/tools/make/trunk/ gnustep-make >/dev/null  || exit 1
echo "  gnustep-base..."
svn co -r $GNUSTEP_REV http://svn.gna.org/svn/gnustep/libs/base/trunk/ gnustep-base >/dev/null  || exit 1
echo "  libdispatch..."
git clone https://github.com/nickhutchinson/libdispatch.git >/dev/null  || exit 1

## Compilation
echo "Compilation"

## Compile gnustep-make
echo "  gnustep-make..."
cd gnustep-make
./configure CC=$CC CXX=$CXX --with-layout=$LAYOUT --prefix="$DEST" || exit 1
make || exit 1
make install
cd ..

. "$DEST/share/GNUstep/Makefiles/GNUstep.sh"

## Compile the Objective-C 2 runtime
echo "  libobjc2..."
cd gnustep-libobjc2
rm -rf build ; mkdir build ; cd build
cmake .. -DCMAKE_INSTALL_PREFIX="$DEST" -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX
make -j$JOBS || exit 1
make install
cd ../../

cd gnustep-make
./configure CC=$CC CXX=$CXX --enable-objc-nonfragile-abi --with-layout=$LAYOUT --prefix="$DEST" || exit 1
make || exit 1
make install
cd ..

. "$DEST/share/GNUstep/Makefiles/GNUstep.sh"

## Compile GNUstep base
echo "  gnustep-base..."
cd gnustep-base
patch -p0 <../../patches/gnustep-base.patch || exit 1
./configure CC=$CC CXX=$CXX --prefix="$DEST" || exit 1
make -j$JOBS || exit 1
make install
cd ..

## Compile libdispatch
echo "  libdispatch..."
cd libdispatch
git checkout $LIBDISPATCH_REV
patch -p1 <../../patches/libdispatch.patch || exit 1
sed -i"" "s/add_subdirectory(testing)/#add_subdirectory(testing)/" CMakeLists.txt
mkdir build
cd build
cmake .. -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_INSTALL_PREFIX="$DEST" -DCMAKE_BUILD_TYPE=Release || exit 1
make || exit 1
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

