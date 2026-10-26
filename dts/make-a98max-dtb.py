#!/usr/bin/env python3
"""Build sun50i-h313-a98max.dtb from the stock DTB shipped in the X96Q Armbian image.

Input : sun50i-h313-x96q-lpddr3.dtb   (from /boot/dtb/allwinner/ of the sicXnull X96Q v1-3 image)
Output: sun50i-h313-a98max.dtb

Needs `dtc` (device-tree-compiler). The edits are done on the decompiled source so that no
third-party DTS has to be redistributed here. Every edit asserts that it matched.

Edits
  1. DRAM rail (AXP313A dcdc3 'vdd-dram'): 1.2 V (LPDDR3) -> 1.5 V (this board has DDR3).
  2. Front LEDs: PH6 'power' (active-low, on) and PH7 'standby' (active-high, off), as in the stock firmware.
     NOTE: the visible front panel is an FD650 controller, see scripts/fd650.py; PH6/PH7 are not that.
  3. Seekwave EA6521QF Wi-Fi: add the `seekwave,sv6160` boot node (chip_en PG19, host_wake PG15).
  4. wifi-pwrseq: use the clock name the mmc-pwrseq-simple driver expects (`ext_clock`) and mux PG10 to the
     32.768 kHz clock output. Without a running 32 kHz clock the Wi-Fi chip never becomes ready.
"""
import re, subprocess, sys

def sh(args, data=None):
    return subprocess.run(args, input=data, check=True, capture_output=True).stdout

def sub1(pattern, repl, s, flags=re.S):
    new, n = re.subn(pattern, repl, s, count=1, flags=flags)
    assert n == 1, "edit did not match: " + pattern[:60]
    return new

def main(src, dst):
    s = sh(["dtc", "-q", "-I", "dtb", "-O", "dts", src]).decode()

    # 1) DRAM voltage 1.2 V -> 1.5 V
    s = sub1(r'(regulator-min-microvolt = <)0x124f80(>;\s*regulator-max-microvolt = <)0x124f80(>;\s*regulator-name = "vdd-dram";)',
             r'\g<1>0x16e360\g<2>0x16e360\g<3>', s)
    s = s.replace('model = "X96Q TV-Box LPDDR3";', 'model = "A98Max+ (H313 DDR3 AXP1530)";')

    # 2) LEDs
    blk = re.search(r'\n\tleds \{.*?\n\t\};\n', s, flags=re.S)
    assert blk, "leds block not found"
    pio = re.search(r'gpios = <(0x[0-9a-f]+) 0x07 0x06', blk.group(0)).group(1)
    leds = ('\n\tleds {\n\t\tcompatible = "gpio-leds";\n\n'
            '\t\tled-power {\n\t\t\tlabel = "power";\n\t\t\tgpios = <%s 0x07 0x06 0x01>;\n'
            '\t\t\tdefault-state = "on";\n\t\t\tlinux,default-trigger = "default-on";\n\t\t};\n\n'
            '\t\tled-standby {\n\t\t\tlabel = "standby";\n\t\t\tgpios = <%s 0x07 0x07 0x00>;\n'
            '\t\t\tdefault-state = "off";\n\t\t};\n\t};\n') % (pio, pio)
    s = s[:blk.start()] + leds + s[blk.end():]

    # 3) Seekwave node (appended last in the root node: dtc wants properties before sub-nodes)
    node = ('\n\tseekwave-wifi {\n\t\tcompatible = "seekwave,sv6160";\n\t\tdma_type = <0x01>;\n'
            '\t\tgpio_chip_en = <%s 0x06 0x13 0x00>;\t/* PG19 */\n'
            '\t\tgpio_host_wake = <%s 0x06 0x0f 0x00>;\t/* PG15 */\n\t\tstatus = "okay";\n\t};\n') % (pio, pio)
    i = s.rstrip().rfind("\n};")
    assert i > 0
    s = s[:i] + "\n" + node + s[i:]

    # 4) pwrseq clock name + PG10 clock-out pinmux (x32clk-fanout-pin already exists in the DTB)
    pin = re.search(r'x32clk-fanout-pin \{[^}]*?phandle = <(0x[0-9a-f]+)>;', s, flags=re.S)
    assert pin, "x32clk-fanout-pin not found"
    s = sub1(r'(wifi-pwrseq \{\s*compatible = "mmc-pwrseq-simple";\s*)clocks = (<[^>]+>);\s*clock-names = "osc32k-out";',
             r'\g<1>pinctrl-names = "default";\n\t\tpinctrl-0 = <%s>;\n\t\tclocks = \g<2>;\n\t\tclock-names = "ext_clock";' % pin.group(1), s)

    open(dst, "wb").write(sh(["dtc", "-q", "-I", "dts", "-O", "dtb"], s.encode()))
    print("wrote", dst)

if __name__ == "__main__":
    if len(sys.argv) != 3: sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
