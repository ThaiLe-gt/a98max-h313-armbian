#!/bin/bash
# Apply the A98Max+ changes to the ROOT FILESYSTEM of an Armbian SD card that is already mounted.
# It only copies files into the directory you give it: it never touches a block device.
#
#   sudo tools/patch-rootfs.sh /mnt/sd path/to/sun50i-h313-a98max.dtb [--wifi path/to/modules-dir path/to/firmware-dir]
#
#   dtb       : built with dts/make-a98max-dtb.py
#   --wifi    : also install the Seekwave modules + firmware and enable seekwave-wifi.service
#   Without --wifi you still get HDMI/Ethernet/Docker-capable system; Wi-Fi stays off.
set -euo pipefail
ROOT=${1:?mounted rootfs dir}; DTB=${2:?dtb}; shift 2
HERE=$(cd "$(dirname "$0")/.." && pwd)
WIFI=0; MODS=""; FW=""
if [ "${1:-}" = "--wifi" ]; then WIFI=1; MODS=${2:?modules dir}; FW=${3:?firmware dir}; fi

[ -d "$ROOT/boot/dtb/allwinner" ] && [ -f "$ROOT/boot/armbianEnv.txt" ] || { echo "$ROOT does not look like an Armbian rootfs"; exit 1; }
[ -f "$DTB" ] || { echo "no such dtb: $DTB"; exit 1; }

# 1) device tree + boot environment
install -m 644 "$DTB" "$ROOT/boot/dtb/allwinner/sun50i-h313-a98max.dtb"
E="$ROOT/boot/armbianEnv.txt"
[ -f "$E.orig" ] || cp -p "$E" "$E.orig"
sed -i '/^fdtfile=/d' "$E"
[ -z "$(tail -c1 "$E")" ] || echo >> "$E"
echo "fdtfile=allwinner/sun50i-h313-a98max.dtb" >> "$E"

# 2) Ethernet: the AC300 PHY needs a 24 MHz clock that only Android switches on
install -m 755 "$HERE/scripts/ac300-ephy-clk.py" "$ROOT/usr/local/sbin/ac300-ephy-clk.py"
install -m 644 "$HERE/scripts/ac300-ephy.service" "$ROOT/etc/systemd/system/ac300-ephy.service"
mkdir -p "$ROOT/etc/systemd/system/sysinit.target.wants"
ln -sf /etc/systemd/system/ac300-ephy.service "$ROOT/etc/systemd/system/sysinit.target.wants/ac300-ephy.service"

# 3) front panel + helper
install -m 755 "$HERE/scripts/fd650.py" "$ROOT/usr/local/sbin/fd650.py"
install -m 755 "$HERE/scripts/connect-wifi" "$ROOT/usr/local/sbin/connect-wifi"

# 4) the image ships a driver stack for a different Wi-Fi chip (UWE5622/AW859A); keep it away from ours
mkdir -p "$ROOT/etc/modprobe.d"
printf '%s\n' '# A98Max+ has a Seekwave EA6521QF, not UWE5622/AW859A' \
  'blacklist sprdwl_ng' 'blacklist sprdbt_tty' 'blacklist uwe5622_bsp_sdio' > "$ROOT/etc/modprobe.d/blacklist-uwe5622.conf"
rm -f "$ROOT/etc/systemd/system/multi-user.target.wants/aw859a-wifi.service" \
      "$ROOT/etc/systemd/system/multi-user.target.wants/aw859a-bluetooth.service"
[ ! -f "$ROOT/etc/modules" ] || sed -i '/^sprdbt_tty$/d' "$ROOT/etc/modules"

# 5) optional Wi-Fi
if [ "$WIFI" = 1 ]; then
  KVER=$(ls "$ROOT/lib/modules" | head -1)
  mkdir -p "$ROOT/lib/modules/$KVER/extra" "$ROOT/lib/firmware" "$ROOT/data/misc/wifi"
  install -m 644 "$MODS"/skw_sdio.ko "$MODS"/skw_bootcoms.ko "$MODS"/skw.ko "$ROOT/lib/modules/$KVER/extra/"
  cp "$FW"/* "$ROOT/lib/firmware/"
  install -m 644 "$HERE/scripts/seekwave-wifi.service" "$ROOT/etc/systemd/system/seekwave-wifi.service"
  mkdir -p "$ROOT/etc/systemd/system/multi-user.target.wants"
  ln -sf /etc/systemd/system/seekwave-wifi.service "$ROOT/etc/systemd/system/multi-user.target.wants/seekwave-wifi.service"
  echo "NOTE: run 'depmod -a' on the booted system once (or: sudo chroot $ROOT depmod -a $KVER)."
fi
sync
echo "done. armbianEnv.txt:"; cat "$E"
