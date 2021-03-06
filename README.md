# Introduction

This is an update of the Hopper
[Linux SDK](https://www.hopperapp.com/blog/?p=150) to match the versions
of libraries shipped by more recent Hopper builds. Download a
[release](https://github.com/ckuethe/HopperSDK-Linux/releases)
to match the target version of Hopper.

# Usage

```
git clone https://github.com/ckuethe/HopperSDK-Linux
cd HopperSDK-Linux
# git checkout v4.1.5 # (optional, match to target Hopper version)
./install.sh

. ${HOME}/hopper-gnustep.sh
# go about your plugin development business.
```

When the build finishes, the SDK will be installed in
`${HOME}/GNUstep/Library/ApplicationSupport/Hopper` as
`HopperSDK-${SDKVER}` and `gnustep-$(arch)`. Additionally a symbolic
link to `GNUstep.sh` - required to set up some environment variables
to compile plugins - will be installed at `${HOME}/hopper-gnustep.sh`.
On a multiuser machine, each user will need to run this SDK installer.

# Notes
* Build prerequisites include `libpthread-workqueue-dev` `libkqueue-dev`
`clang` `libblocksruntime-devel`
* On recent Ubuntu (17.04) `libxml2-dev` `libgnutls28-dev` `libxslt1-dev`
`libgcrypt20-dev` are also required to compile GNUstep base
