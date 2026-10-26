#!/usr/bin/python3
# Enable the 24 MHz clock the co-packaged AC300 EPHY needs (PWM5 bypass on PA12),
# replicating the register state the stock Android firmware leaves behind.
import mmap, os, struct

def rmw(addr, clr, set_):
    page = addr & ~0xfff
    off = addr - page
    fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
    try:
        m = mmap.mmap(fd, 0x1000, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE, offset=page)
        old = struct.unpack_from("<I", m, off)[0]
        struct.pack_into("<I", m, off, (old & ~clr) | set_)
        new = struct.unpack_from("<I", m, off)[0]
        m.close()
    finally:
        os.close(fd)
    return old, new

steps = [
    ("CCU PWM_BGR: bus gate + deassert reset", 0x030017AC, 0x00000000, 0x00010001),
    ("PA12 mux -> function 2 (pwm5)",          0x0300B004, 0x000F0000, 0x00020000),
    ("PWM PCGR: PWM5 clock gate",              0x0300A040, 0x00000000, 0x00000020),
    ("PWM PCCR45: OSC24M, gate, PWM5 bypass",  0x0300A028, 0x000001FF, 0x00000050),
]

for name, addr, clr, set_ in steps:
    old, new = rmw(addr, clr, set_)
    print("%s 0x%08x: 0x%08x -> 0x%08x" % (name, addr, old, new))
