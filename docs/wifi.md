# Seekwave EA6521QF Wi-Fi on Linux 6.12

## Source

The driver is the GPL-2.0 Seekwave tree published in
[TinkerBoard-Android/rockchip-android-external-wifi_driver](https://github.com/TinkerBoard-Android/rockchip-android-external-wifi_driver)
(branch `android14-rockchip`, commit `88acf64dbc91f082045dd465ec4d4497f09f2f37`, directory `ea6621q`, version string `2.0.240304.e998adb`).
It targets Android kernels; [`wifi/seekwave-6.12-port.patch`](../wifi/seekwave-6.12-port.patch) makes it build on 6.12.64:

* `platform_driver.remove` now returns `void` (three drivers wrapped);
* `class_create()` lost its `THIS_MODULE` argument;
* `of_get_named_gpio_flags()` replaced by `of_get_named_gpio()`;
* RPS structures moved to `<net/rps.h>`, `<net/netdev_rx_queue.h>`; `local_clock()` needs `<linux/sched/clock.h>`;
* cfg80211: `change_beacon` takes `struct cfg80211_ap_update`, `tdls_mgmt` gained `link_id`, `cfg80211_rx_assoc_resp` became
  `..._data`, `cfg80211_ch_switch_started_notify` lost an argument, `crypto.wep_keys` is gone, `wdev->mtx` is gone (now `wiphy_lock`);
* the Rockchip-only `rockchip_wifi_mac_addr()` call and header are removed (the chip's own MAC is used).

Build: `wifi/build-modules.sh /path/to/config-6.12.64-current-sunxi64` → `out/skw_sdio.ko`, `out/skw_bootcoms.ko`, `out/skw.ko`.
The modules are only valid for exactly that kernel (no `MODVERSIONS`, vermagic `6.12.64-current-sunxi64 SMP mod_unload aarch64`).

## Firmware (not included, proprietary)

Copy these from **your own box's Android partition** (`/vendor/etc/firmware/` in the vendor image inside `super`), e.g. with `adb pull`
on a rooted box, or by reading the `vendor_a` logical partition:

```
RAM_RW_KERNEL_DRAM.bin        ROM_EXEC_KERNEL_IRAM.bin
EA6521QF_SEEKWAVE_R00005.bin  EA6521QF_SEEKWAVE_R00005.ini
```

Put them in `/lib/firmware/`. The driver logs `fw file: EA6521QF_SEEKWAVE_R00005.bin` when it asks for the calibration file.

## Device tree and bring-up order

`dts/make-a98max-dtb.py` adds a `seekwave,sv6160` node and fixes `wifi-pwrseq` (clock name `ext_clock`, PG10 pinmux). Then:

```bash
modprobe skw_bootcoms     # downloads firmware, expect: "LOOPCHECK channel received: ... trunk_W23..." and no "CP-ready time out"
modprobe skw              # expect "WIFIREADY" and a wlan0 interface
sudo connect-wifi "SSID"  # asks for the password on the terminal
```

`scripts/seekwave-wifi.service` loads `skw` at boot with a 60 s timeout so a driver problem cannot block booting.
