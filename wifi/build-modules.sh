#!/bin/bash
# Build skw_sdio.ko, skw_bootcoms.ko, skw.ko for the Armbian 6.12.64-current-sunxi64 kernel.
# Needs: Docker, the running kernel's config, and ~1.5 GB of disk. Output: ./out/*.ko
# Usage: wifi/build-modules.sh path/to/config-6.12.64-current-sunxi64   (copy it from /boot on the box)
set -euo pipefail
cd "$(dirname "$0")/.."
KCONF=${1:?path to /boot/config-6.12.64-current-sunxi64 from the box}
KVER=6.12.64
docker build -q -t a98max-build .
mkdir -p cache out
[ -f cache/linux-$KVER.tar.xz ] || curl -fsSL -o cache/linux-$KVER.tar.xz https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KVER.tar.xz
cp "$KCONF" cache/kconfig-box
docker run --rm -v "$PWD":/repo -v "$PWD/cache":/work -w /work a98max-build bash -euo pipefail -c '
  [ "$(uname -m)" = aarch64 ] || { export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-; }
  [ -d linux-'$KVER' ] || tar -xf linux-'$KVER'.tar.xz
  cd linux-'$KVER'; cp ../kconfig-box .config; make olddefconfig >/dev/null
  make LOCALVERSION=-current-sunxi64 modules_prepare -j"$(nproc)" >/tmp/prep.log 2>&1
  cd /work; rm -rf wifi-src; mkdir wifi-src
  # original Seekwave sources: TinkerBoard-Android/rockchip-android-external-wifi_driver, branch android14-rockchip
  # (head 88acf64dbc91f082045dd465ec4d4497f09f2f37, directory ea6621q)
  curl -fsSL https://codeload.github.com/TinkerBoard-Android/rockchip-android-external-wifi_driver/tar.gz/88acf64dbc91f082045dd465ec4d4497f09f2f37 | tar -xz -C wifi-src --strip-components=2 rockchip-android-external-wifi_driver-88acf64dbc91f082045dd465ec4d4497f09f2f37/ea6621q
  cd wifi-src; git init -q .; git apply /repo/wifi/seekwave-6.12-port.patch; cd /work
  # KBUILD_MODPOST_WARN: skw_sdio/skw export symbols the other two use; modpost needs the first pass to finish
  make -C linux-'$KVER' M=/work/wifi-src LOCALVERSION=-current-sunxi64 KBUILD_MODPOST_WARN=1 modules -j"$(nproc)" >/tmp/m.log 2>&1 || { grep -E " error: |ERROR" /tmp/m.log | head -20; exit 1; }
  find wifi-src -name "*.ko" -exec cp {} /repo/out/ \;
'
ls -l out/*.ko
