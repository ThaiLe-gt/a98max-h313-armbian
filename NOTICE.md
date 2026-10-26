# Third-party material

| Path | What | Licence / origin |
|---|---|---|
| `uboot/a98max_defconfig` | derived from `x96q_defconfig` of U-Boot | GPL-2.0-or-later, [U-Boot](https://source.denx.de/u-boot/u-boot) v2026.10 (`5508406582f6f7120dce0c4b3059819a41788db2`) |
| `uboot/sun50i-h313-a98max.dts` | derived from `sun50i-h313-x96q.dts` © 2025 J. Neuschäfer | (GPL-2.0-or-later OR MIT), SPDX header kept |
| `uboot/prebuilt/u-boot-sunxi-with-spl.bin` | binary built from the two lines above plus ARM Trusted Firmware v2.15.0 (`da738d5eae93af342fdc4995dd3c05acb4c9d757`, BSD-3-Clause) | GPL-2.0-or-later (U-Boot). Corresponding source: the upstream tags above + the files in `uboot/` |
| `wifi/seekwave-6.12-port.patch` | modifications to the Seekwave driver ([TinkerBoard-Android/rockchip-android-external-wifi_driver](https://github.com/TinkerBoard-Android/rockchip-android-external-wifi_driver), `ea6621q`, SPDX GPL-2.0) | GPL-2.0, same as the code it modifies |
| `scripts/fd650.py` | FD650 protocol re-implemented after the Amlogic `fd650.c` driver ([source](https://nest-open-source.googlesource.com/manifest_repos/amlogic-driver/+/3bd4d38801cb93b3c1e3f73f69eb77f093660f09/drivers/led/fd650.c), `GPL-2.0+ OR MIT`) | MIT (this repo) |

**Not included, on purpose:** the Armbian image, any Android/Allwinner firmware (`boot0`, vendor partitions), the Seekwave firmware blobs,
and the decompiled Android device tree (it contains the unit's serial number and MAC address).
"Armbian" and "Tanix" are names of their respective owners; this project is not affiliated with either.
