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

## The `setup TXBA failed, ret: -1` message (explained, harmless)

`[SKWIFI ERROR] skw_work_process: setup TXBA failed, ret: -1` appears **once per association** and nothing else. Reproduced 3 out of 3 times by taking
`wlan0` down and up (and it appears once at boot when Wi-Fi first connects). Sequence seen in the kernel log each time, times relative to
`ASSOCED -> COMPLETED`:

| t | event |
|---|---|
| +10 ms | driver queues TX Block-Ack setup for **TID 0** |
| +28 ms | driver queues the same for **TID 6** (voice queue); it is **rejected in under 1 ms** → the error line |
| +80 ms | TID 0 completes: `ADD_TX_BA ... tid: 0, status: 0, win size: 64` |
| +150 ms | driver asks again for TID 6 and it succeeds: `ADD_TX_BA ... tid: 6, status: 0, win size: 64` |

In the driver `ret = 0 - skw->cmd.status`, so `-1` is a status code 1 returned by the chip, not a timeout and not a local error (`skw_msg_xmit_timeout`).
Reading of the timing (an inference, the chip firmware is closed): two `BA_ACTION` commands are issued back to back right after the connection completes
and the second one is refused while the first is still being handled; the retry on the next frame succeeds. End result: every TID gets its Block-Ack, no
disconnect, and the per-TID retry counter (`txba.tx_try`, blacklist after more than 5 failures) never gets near its limit.

What did *not* trigger it: pings with various TOS values, UDP sockets with `SO_PRIORITY=6`, DHCP renewals and full DHCP restarts. If you want the message gone,
either serialise the BA requests in `skw_setup_txba()` or demote the log line in `skw_work.c`; neither was done here.

## Things that are not solved

* No kernel driver for the FD650 panel: a Python process bit-bangs two GPIOs through sysfs (works, but it is a userspace hack and wakes once per second).
* The ported Wi-Fi driver replaces `wdev->mtx` by `wiphy_lock()`. It runs, but this was changed to compile, not reviewed against the cfg80211 locking rules.
