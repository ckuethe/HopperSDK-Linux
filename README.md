# Introduction

This is an update of the Hopper
[Linux SDK](https://www.hopperapp.com/blog/?p=150) to match the versions
of libraries shipped by more recent Hopper builds.

# Usage

```
git clone https://github.com/ckuethe/HopperSDK-Linux
cd HopperSDK-Linux
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
* On recent Ubuntu (17.04) `libxml2-dev` `libgnutls28-dev` `libxslt1-dev`
`libgcrypt20-dev` are required to compile GNUstep base
