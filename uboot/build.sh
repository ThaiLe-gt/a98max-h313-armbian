#!/bin/bash
# Build u-boot-sunxi-with-spl.bin for the A98Max+ inside Docker.
# Tested on an arm64 host (native toolchain). On x86-64 the cross compiler path is untested.
# Output: ./out/u-boot-sunxi-with-spl.bin
set -euo pipefail
cd "$(dirname "$0")/.."
UBOOT_TAG=v2026.10      # built and tested with commit 5508406582f6f7120dce0c4b3059819a41788db2
TFA_TAG=v2.15.0         # commit da738d5eae93af342fdc4995dd3c05acb4c9d757
docker build -q -t a98max-build .
mkdir -p out cache
docker run --rm -v "$PWD":/repo -v "$PWD/cache":/work -w /work a98max-build bash -euo pipefail -c '
  [ "$(uname -m)" = aarch64 ] || export CROSS_COMPILE=aarch64-linux-gnu-
  [ -d u-boot ] || git clone -q --depth 1 --branch '"$UBOOT_TAG"' https://source.denx.de/u-boot/u-boot.git
  [ -d tf-a ]   || git clone -q --depth 1 --branch '"$TFA_TAG"' https://github.com/ARM-software/arm-trusted-firmware.git tf-a
  make -C tf-a PLAT=sun50i_h616 DEBUG=0 bl31 -j"$(nproc)" >/tmp/tfa.log 2>&1 || { tail -20 /tmp/tfa.log; exit 1; }
  cp /repo/uboot/sun50i-h313-a98max.dts u-boot/dts/upstream/src/arm64/allwinner/sun50i-h313-a98max.dts
  cp /repo/uboot/a98max_defconfig u-boot/configs/a98max_defconfig
  make -C u-boot a98max_defconfig >/dev/null
  make -C u-boot BL31=/work/tf-a/build/sun50i_h616/release/bl31.bin -j"$(nproc)" >/tmp/uboot.log 2>&1 || { tail -30 /tmp/uboot.log; exit 1; }
  cp u-boot/u-boot-sunxi-with-spl.bin /repo/out/
'
sha256sum out/u-boot-sunxi-with-spl.bin
echo "(the binary embeds a build timestamp, so its hash differs from uboot/prebuilt/ even though the sources are the same)"
