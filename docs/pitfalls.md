# Pitfalls and how they were found

In the order they were hit.

1. **Fake SD cards.** Two of the three cards tried were bad. One reported 62.5 GB but only 7.77 GB were real (`f3probe`: "counterfeit, type limbo").
   Always run `f3probe --destructive /dev/xxx` on a new card (it erases it).
2. **A wrong test gave a wrong answer.** An early home-made capacity test said the fake card had "2 GB". That number was an artefact:
   the 32-bit `busybox dd` on Android cannot seek past 2 GiB, so reads at ≥ 2100 MiB failed. The conclusion "fake" was right, the number was not.
   Use a 64-bit `dd` (Debian's) or `f3`.
3. **A bootloader that hangs without any output.** There was no UART. Causes that were ruled in or out, in order:
   * Armbian's X96Q image expects an AXP305 PMIC; this board has an AXP1530 (reads as AXP313A).
   * The DTB the X96Q U-Boot looks for (`sun50i-h313-x96q.dtb`) is not even in the image.
   * The U-Boot device tree declared card-detect on PF6 (the real pin is PI16) and an AXP305 PMIC node, which TF-A also reads.
     The first boot that worked changed both at once (AXP313A node + `broken-cd`), so **which of the two was the decisive fix was not isolated**.
     The working theory was that U-Boot saw "no card" and stopped at its prompt.
   * The kernel DT sets the DRAM rail to 1.2 V (LPDDR3). The board has DDR3 and needs 1.5 V.
4. **Debugging without a serial port.** U-Boot's `preboot` and the patched `boot.scr` wrote markers into unused SD sectors (3–4 MiB), which were read
   back from Android afterwards. That narrowed the failure down to a stage. If you see a hang, this technique is worth a day of guessing.
5. **Ethernet `No PHY found`**: the 24 MHz PHY clock, see hardware.md.
6. **Wi-Fi never ready**: the 32.768 kHz clock. `mmc-pwrseq-simple` only enables a clock named **`ext_clock`**; a node using `osc32k-out` as the
   clock name is silently ignored, and PG10 must be muxed to the clock output.
7. **Android mounts the SD card by itself** (`vold`), so `mount` on the card's partition says "busy". `sm unmount public:179,49` first.

## Things that are not solved

* No driver for the FD650 panel in the kernel; the script only bit-bangs it.
* `skw` logs `setup TXBA failed` now and then (block-ack setup). Not investigated.
* The ported Wi-Fi driver replaces `wdev->mtx` by `wiphy_lock()`. It runs, but this was changed to compile, not reviewed against the cfg80211 locking rules.
