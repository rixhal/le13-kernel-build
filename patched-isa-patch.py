#!/usr/bin/env python3
import struct
import sys

BIN = "/home/richal/le13-kernel-build/isa-22.3.11/build/inputstream.adaptive.so.20.5"

with open(BIN, "rb") as f:
    data = bytearray(f.read())

# PATCH 1: Failure path at 0x12dab4
# Original: orr w0, w0, #0x6   = 0x321f0400 (SSD_SECURE_PATH | SSD_ANNEXB_REQUIRED)
# Target:   orr w0, w0, #0x10  = 0x321c0000 (SSD_SINGLE_DECRYPT)
new_val = 0x321c0000

for name, addr in [("FAILURE path", 0x12dab4), ("EXCEPTION path", 0x12dc14)]:
    old = struct.unpack('<I', data[addr:addr+4])[0]
    print(f"PATCH {name} @ 0x{addr:x}: 0x{old:08x} → 0x{new_val:08x}")
    struct.pack_into('<I', data, addr, new_val)

# Verify both
for addr in [0x12dab4, 0x12dc14]:
    v = struct.unpack('<I', data[addr:addr+4])[0]
    ok = "✅" if v == new_val else "❌"
    print(f"  Verify @ 0x{addr:x}: 0x{v:08x} {ok}")

# Write back
with open(BIN, "wb") as f:
    f.write(data)

print("\nBinary patched successfully!")
