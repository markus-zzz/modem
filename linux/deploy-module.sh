#!/bin/bash

set -xe

pushd $ZZZ_ROOT/modem/linux
make CROSS_COMPILE=arm-linux-gnueabihf- ARCH=arm -C $ZZZ_ROOT/linux M=${PWD} modules

cp $ZZZ_ROOT/modem/linux/*.ko $ZZZ_ROOT/busybox/_install/
pushd $ZZZ_ROOT/busybox/_install
find . -print0 | cpio --null -ov --format=newc | gzip -9 > $ZZZ_ROOT/initramfs.cpio.gz
popd
popd
