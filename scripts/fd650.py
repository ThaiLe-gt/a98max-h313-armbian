#!/usr/bin/python3
"""Drive the front-panel FD650 LED controller (2-wire, I2C-like, no ACK) over bit-banged GPIO.
Pins from the stock firmware: CLK = PI11 (gpio 267), DAT = PI12 (gpio 268).
Protocol from the Amlogic fd650 driver: start, byte((cmd>>7)&0x3e|0x40), byte(cmd&0xff), stop."""
import os, sys, time

CLK, DAT = 267, 268
SYS_ON_MAX = 0x0401           # display on, brightness 8 (max)
SYS_OFF = 0x0400
DIG = (0x1400, 0x1500, 0x1600, 0x1700)
DOT = 0x80
SEG = {"0":0x3F,"1":0x06,"2":0x5B,"3":0x4F,"4":0x66,"5":0x6D,"6":0x7D,"7":0x07,"8":0x7F,"9":0x6F,
       "a":0x77,"b":0x7C,"c":0x58,"d":0x5E,"e":0x79,"f":0x71,"-":0x40," ":0x00,"o":0x5C,"t":0x78,"n":0x54,
       "r":0x50,"l":0x38,"p":0x73,"u":0x1C,"h":0x74,"i":0x10,"s":0x6D}

def gp(n, direction=None):
    d = "/sys/class/gpio/gpio%d" % n
    if not os.path.isdir(d):
        open("/sys/class/gpio/export", "w").write(str(n))
        for _ in range(50):
            if os.path.isdir(d): break
            time.sleep(0.02)
    if direction: open(d + "/direction", "w").write(direction)
    return open(d + "/value", "wb", buffering=0)

class Bus:
    def __init__(self):
        self.scl = gp(CLK, "out"); self.sda = gp(DAT, "out")
    def s(self, f, v): f.write(b"1" if v else b"0")
    def start(self):
        self.s(self.sda, 1); self.s(self.scl, 1); self.s(self.sda, 0); self.s(self.scl, 0)
    def stop(self):
        self.s(self.sda, 0); self.s(self.scl, 1); self.s(self.sda, 1)
    def byte(self, b):
        for i in range(8):
            self.s(self.sda, b & 0x80); self.s(self.scl, 1); b = (b << 1) & 0xFF; self.s(self.scl, 0)
        self.s(self.sda, 1); self.s(self.scl, 1); self.s(self.scl, 0)   # ack clock, ignored
    def write(self, cmd):
        self.start(); self.byte(((cmd >> 7) & 0x3E) | 0x40); self.byte(cmd & 0xFF); self.stop()

def show(bus, segs):
    bus.write(SYS_ON_MAX)
    for i, v in enumerate(segs[:4]):
        bus.write(DIG[i] | v)

def text(s):
    out, i = [], 0
    s = s.lower()
    while i < len(s) and len(out) < 4:
        v = SEG.get(s[i], 0)
        if i + 1 < len(s) and s[i + 1] == ".": v |= DOT; i += 1
        out.append(v); i += 1
    return out + [0] * (4 - len(out))

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    b = Bus()
    if cmd == "all":   show(b, [0xFF] * 4)
    elif cmd == "off": b.write(SYS_OFF)
    elif cmd == "text": show(b, text(sys.argv[2]))
    elif cmd == "raw":  show(b, [int(x, 0) for x in sys.argv[2:6]])
    else: sys.exit("usage: fd650.py all|off|text STR|raw A B C D")
