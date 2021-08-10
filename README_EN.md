# RedPill Tool Chain

[中文说明](README.md "English")
THX @haydibe

# What is this?

The redpill tool chain docker image builder is updated to v0.4:

- proper DSM7 support for apollolake (thnx @jumkey)
- switched from kernel sources based build to toolkit dev based builds for DSM6.2.4 and DSM7.0 (thnx @jumkey) 
- make targets for bromolow and apollolake merged: platform and version must be configure in the Makefile now
- image is ~720-780MB instead of ~1.200-1.500MB now

 
> PS: since toolkit dev lacks the required sources for fs/proc, they are taken from the extracted DSM6.2.4 kernel sources.
The build requires the sources for this single folder, but does not use the kernel source to build the redpill.ko module. 

If you see something is wrong in how the toolchain is build or have ideas how to make it better: please let me know.

For every other problem: please address it to the community - I don't know more than others do. 

> PS2: before someone asks: I haven't managed a successfull installation/migration with the created bootloader so far. I am testing exclusivly on ESXi 6.7. The migration always stops at 56% and bails out with error 13.

 
# How to use it?

1. (on host) configure the Makefile and configure TARGET_PLATFORM (default: bromolow) and TARGET_VERSION (default: 6.2 - will build 6.2.4)
1. (on host) create your own user_config.json or edit the USERCONFIG_* variables in the Makefile
1. (on host) build image: make build_image
1. (on host) build boot image: make build_boot

After running `make build_boot` the created redpill bootloader image will be present in the ./image folder on the host.
 
Tested with hosts: Ubuntu 18.04 VM, Ubuntu 20.04 WSL2 and XPE  (the make binary to build on Synology/XPE can be found here)

Dependencies: make and docker