# Armbian on the "A98Max+" Allwinner H313 TV box (sold as "Tanix TX3 mini Plus")

Booting **Armbian from a microSD card** on an Android TV box whose label says *TX3 mini Plus
2GB+16GB+2.4G+5G* but which is **not** the Amlogic Tanix product: inside it is an **Allwinner H313**
(H616 family). This repository holds the pieces that were needed to make it work: a bootloader build, a
device tree, an Ethernet fix, a ported Wi-Fi driver, and the notes on how each problem was found.

> **Status: works on one unit (the author's).** Other boxes sold under the same name may differ.
> Nothing here touches the box's internal eMMC: remove the SD card and it boots Android again.
> No firmware, no Armbian image and no Android files are redistributed here. Use at your own risk.

## What works (tested on one unit)

| Feature | State | Notes |
|---|---|---|
| Boot from SD (mainline U-Boot 2026.10 + TF-A 2.15) | works | custom build, see [`uboot/`](uboot) |
| HDMI console | works | seen on a TV |
| Ethernet (100 M) | works | needs the AC300 PHY clock fix, see [`scripts/ac300-ephy-clk.py`](scripts/ac300-ephy-clk.py) |
| Wi-Fi 2.4 GHz (Seekwave EA6521QF) | works | scan, WPA2 connect, ~44 Mbit/s, survives reboot. **5 GHz not tested** |
| Docker 29.x | works | `hello-world`, memory/pids/cpu limits, NAT networking verified |
| Front panel (FD650, 4-digit display) | works | shows the time (HHMM) via `scripts/fd650.py clock`; confirmed by the owner. Digit order and blinking colon were not inspected in detail |
| Bluetooth, audio, IR, USB-OTG | not tried | |
| Wi-Fi driver stability | limited testing | one harmless `setup TXBA failed` per association ([explained](docs/pitfalls.md#the-setup-txba-failed-ret--1-message-explained-harmless)); no disconnects seen so far |

## Hardware (read from the box, see [`docs/hardware.md`](docs/hardware.md))

H313 (4× Cortex-A53, `sun50iw9p1`), 2 GB **DDR3 @ 600 MHz**, 16 GB eMMC, PMIC **AXP1530** (AXP313A-compatible,
I²C 0x36), Ethernet through the co-packaged **AC300** PHY on EMAC1, Wi-Fi/BT **Seekwave EA6521QF** on SDIO,
front-panel **FD650** on PI11/PI12.

## How to reproduce

You need: this box, a **genuine** microSD card (test it with `f3probe`; see the pitfalls doc), a Linux or macOS
computer with Docker, and a way to log in (HDMI + USB keyboard, or Ethernet + SSH).

1. **Get the base image** (not included): `Armbian-unofficial_26.02.0-trunk_X96q-v1-3_bookworm_current_6.12.64_minimal.img.xz`
   from <https://github.com/sicXnull/armbian-build/releases/tag/v24.8.0-trunk.425>
   (sha256 `297d42a09e70d23acd4654e9c6f9289b17153f52f6e72f3fed1c0db666aa20db`). It is an unofficial community build;
   read what you run as root. Flash it to the card with your usual tool.
2. **Bootloader**: the stock X96Q U-Boot hangs on this board (wrong PMIC, wrong DRAM voltage, wrong card-detect pin).
   Either use [`uboot/prebuilt/u-boot-sunxi-with-spl.bin`](uboot/prebuilt) or build it with `uboot/build.sh`. Write it to the card at 8 KiB:
   ```bash
   sudo dd if=u-boot-sunxi-with-spl.bin of=/dev/sdX bs=1k seek=8 conv=fsync
   ```
3. **Device tree**: `dts/make-a98max-dtb.py` rebuilds `sun50i-h313-a98max.dtb` from the DTB inside the image
   (`sun50i-h313-x96q-lpddr3.dtb`). Needs `dtc`.
4. **Apply to the card's root filesystem** (mounted on Linux): `sudo tools/patch-rootfs.sh /mnt/sd sun50i-h313-a98max.dtb`.
   It installs the DTB, the Ethernet clock service, the front-panel clock and helpers, and disables the image's wrong-chip Wi-Fi stack.
5. Boot with HDMI and the network cable connected. Armbian asks you to create a user on first login.
6. **Wi-Fi (optional)**: build the modules with `wifi/build-modules.sh`, copy the four firmware files from the
   box's own Android partition (see [`docs/wifi.md`](docs/wifi.md)), then re-run `patch-rootfs.sh` with `--wifi`.
   Connect with `sudo connect-wifi "SSID"` (the password is typed on the box and never leaves it).

`tools/patch-rootfs.sh` was tested on a fake rootfs tree in a Linux container (run twice to check it is idempotent).
The complete flow was done by hand on real hardware; **the combined procedure above has not been replayed from scratch.**

## Repository layout

```
uboot/     defconfig + device tree + build script + prebuilt binary (+ sha256)
dts/       make-a98max-dtb.py: derive the kernel DTB (no third-party DTS is copied here)
wifi/      port of the Seekwave driver to Linux 6.12 (patch), module build + notes
scripts/   ac300-ephy-clk.py (+unit), seekwave-wifi.service, connect-wifi, fd650.py (+ clock unit)
tools/     patch-rootfs.sh
docs/      hardware.md, pitfalls.md, wifi.md
```

## Warnings

* Wrong settings can leave the box unbootable *from the SD card*; removing the card restores Android.
* The Wi-Fi driver is third-party code, ported by hand, running in the kernel. Treat it accordingly.
* The kernel in the base image is pinned: the modules only match `6.12.64-current-sunxi64`. Do not upgrade the kernel without rebuilding them.
* Do not trust the box's Android firmware: it reports itself as a *Google Pixel 6 Pro* (`google/raven`).

Vietnamese: [README.vi.md](README.vi.md). Licences: [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
