# Hardware notes (A98Max+ / "TX3 mini Plus", Allwinner H313)

Everything below was read from one unit, from the running Android 13 firmware
(`VTTV_H313_6521QF_A98RM_ATV13_2025_V8.6`) or from the Armbian system. Values in *italics* are inferred, not measured.

## Identification

| Item | Value |
|---|---|
| Label under the box | `TX3 mini Plus`, `2GB+16GB+2.4G+5G` |
| Android model / board | `A98Max+` / `sun50iw9p1` |
| Android fingerprint | `google/raven/raven:13/...` (spoofed; this is not a Pixel) |
| Device tree `compatible` | `allwinner,h616`, `arm,sun50iw9p1` (the box is the cheaper H313 bin of the family) |
| Genuine Tanix TX3 Mini+ | Amlogic S905W2 ([androidpctv](https://androidpctv.com/tanix-tx3-mini-plus/)), a different chip |
| Secure boot | `sunxi_secure: normal` (efuse secure boot not reported); Android's verified-boot state reads "locked" and this was never changed |
| Android userspace | 32-bit (`armv8l`), kernel 5.4.125 vendor tree |

## SoC, memory, storage

* 4× Cortex-A53, 2 GB RAM, eMMC 14.5 GB (`mmcblk0` in Android, `mmcblk2` under Armbian when booted from SD).
* Boot ROM prefers the SD card: `eGON.BT0` at 8 KiB of the card is run first. On the eMMC the stock `boot0` sits at 8 KiB (copy at 256 KiB).
* **DRAM parameters** live in the stock `boot0` (32 words at offset 0x38 of the `boot0` image) and in the Android DT (`/dram`).
  Mapping to the mainline U-Boot options (`DRAM_SUNXI_*`):

  | Field | Stock value | Mainline option |
  |---|---|---|
  | clock | 600 MHz | `CONFIG_DRAM_CLK=600` |
  | type | 3 = DDR3 | `CONFIG_SUNXI_DRAM_H616_DDR3_1333` |
  | dx_odt | `0x03030303` | `DRAM_SUNXI_DX_ODT` |
  | dx_dri | `0x0e0e0e0e` | `DRAM_SUNXI_DX_DRI` |
  | ca_dri | `0x1f12` | `DRAM_SUNXI_CA_DRI` |
  | odt_en | `0x1` | default |
  | tpr0 / tpr2 / tpr6 | `0xc0001002` / `0` / `0x33808080` | `TPR0` / (unset) / `TPR6` |
  | tpr10 / tpr11 / tpr12 | `0x002f1107` / `0xddddcccc` / `0xeddc7665` | `TPR10` / `TPR11` / `TPR12` |

  The array positions were matched to the option names by comparing values with mainline's `x96q_defconfig` (not from vendor documentation).
  The board's values are almost identical to that defconfig; the differences are the PMIC and `tpr2`/`tpr10`.

## Power (PMIC)

* **AXP1530** on R_I2C (TWI at 0x07081400), address **0x36**. Register `0x03` reads `0x4b`, which U-Boot and TF-A treat as an AXP313(A)
  (`0x4b & 0xc8 == 0x48`), so `CONFIG_AXP313_POWER` is the right driver.
* Rails measured on the running Android: DCDC1 0.96 V (GPU/sys), DCDC2 1.12 V (CPU), **DCDC3 1.5 V (DDR3)**, ALDO1 1.8 V, DLDO1 3.3 V
  (registers `0x13`, `0x14`, `0x15` read `0x2e`, `0xbe`, `0x55`; bit 7 of `0x14` is a mode flag).
* Armbian's `x96q-lpddr3` DT sets the DRAM rail to 1.2 V (LPDDR3). On this DDR3 board that is wrong; `dts/make-a98max-dtb.py` fixes it.

## Ethernet

* `allwinner,sunxi-gmac` at **0x05030000** (EMAC1), RMII, `tx-delay=7`, `rx-delay=31`.
* PHY: **AC300** (co-packaged). MDIO address 0 answers with ID `0x00441400`; address `0x10` answers `0xc0000000` (control block).
* The PHY only answers once it gets a 24 MHz clock. Android generates it from **PWM5 on PA12** (bypass mode). The kernel in the Armbian image does
  not, so the driver prints `No PHY found!` and `phy init failed`. `scripts/ac300-ephy-clk.py` replays the four register writes:

  | Register | Meaning | Value after |
  |---|---|---|
  | `0x030017AC` | CCU PWM bus gate + reset | `0x00010001` |
  | `0x0300B004` | PA pin mux, PA12 → function 2 (pwm5) | bits [19:16] = 2 |
  | `0x0300A040` | PWM clock gate, PWM5 | bit 5 |
  | `0x0300A028` | PWM clock config (OSC24M, gate, bypass for PWM5) | `0x50` |

  The values were read from the live Android through the Allwinner `sunxi_dump` sysfs interface (`/sys/class/sunxi_dump`).
  It must run before the network comes up: `ac300-ephy.service` is ordered `Before=systemd-networkd.service`.

## Wi-Fi / Bluetooth

* **Seekwave EA6521QF** (SV6160 family, chip id `0x6160`) on SDIO, SMHC1 (`0x04021000`).
* Needs: **32.768 kHz clock on PG10** (RTC `osc32k-out` fan-out), `chip_en` = PG19, `regon`/reset = PG18, `host_wake` = PG15, 3.3 V on DLDO1.
* Without the 32 kHz clock the firmware downloads but the chip never becomes ready (`check CP-ready time out`).
* The Android image's own modules: `skw_sdio.ko`, `skw_bootcoms.ko`, `skw.ko`. Open source from the Rockchip/Tinker Board tree, see [wifi.md](wifi.md).
* The Armbian image ships drivers for a different chip (UWE5622/AW859A); they print errors forever. Blacklist them.

## Front panel and LEDs

* The visible front indicator is an **FD650** LED controller (2-wire, I²C-like, no ACK) on **PI11 = CLK, PI12 = DAT** (stock DT `oranth,fd650`).
  `scripts/fd650.py` implements the protocol from the Amlogic driver and bit-bangs it through sysfs GPIO.
  **Works on hardware**: the owner confirmed that `fd650.py all` lights the panel and that `fd650.py clock` (run by `fd650-clock.service`) shows the time.
  Layout used (taken from the Amlogic driver, not checked segment by segment): the dot of digit 1 is the blinking colon, the dots of digits 0 and 3 stay lit,
  the dot of digit 2 (lock icon) is off.
* PH6 and PH7 are also named `normal_led`/`standby_led` in the stock DT (`gpio_para`). Driving them was not observed to light anything.

## Other

* SD card slot card-detect: stock uses **PI16**. The X96Q device tree uses PF6, so U-Boot believed the slot was empty. This repo uses `broken-cd`.
* UART0 at `0x05000000` is the stock console (`ttyAS0`, 115200). Pad locations on the PCB were not identified.
