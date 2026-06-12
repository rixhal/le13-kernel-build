# le13-widevine-kernel — RPi5 Kernel mit CONFIG_DMABUF_HEAPS_RESERVED=y

## Warum

LE13-Nightlies (Kernel 6.18.x) haben `CONFIG_DMABUF_HEAPS_RESERVED=n`.
Ohne diesen reservierten DMA-Heap kann Widevine auf RPi5 keinen Secure-Decode-Pfad
aufbauen → `Resolution max for secure decoder: 0x0` → RGB-Testpattern.

DRMPRIME ist auf RPi5/LE13 kompiliert und nicht abschaltbar.
Der einzig persistente Fix: Kernel mit `CONFIG_DMABUF_HEAPS_RESERVED=y` bauen.

## Delta zur LE13-Defconfig

NUR eine Zeile ändert sich gegenüber der offiziellen LE13-Kernel-Config:
```
CONFIG_DMABUF_HEAPS_RESERVED=y
```

Keine anderen Änderungen nötig. `CONFIG_OF_RESERVED_MEM` ist bereits gesetzt.

## Quick Start

```bash
# 1. Kernel-Quellen pullen (shallow, nur rpi-6.18.y)
./pull-source.sh

# 2. Bauen (nativ auf Pi 4/5, ~45-90 Minuten)
./build.sh

# 3. kernel.img deployen
scp build-output/kernel.img root@10.10.10.140:/storage/kernel-widevine.img
ssh root@10.10.10.140 '
  mount -o remount,rw /flash
  cp /storage/kernel-widevine.img /flash/kernel.img
  sync
  mount -o remount,ro /flash
  echo b > /proc/sysrq-trigger
'
```

## Verifikation

```bash
ssh root@10.10.10.140 "modprobe configs; zcat /proc/config.gz | grep DMABUF_HEAPS_RESERVED"
# Erwartet: CONFIG_DMABUF_HEAPS_RESERVED=y
```

## Source

- Kernel: [raspberrypi/linux](https://github.com/raspberrypi/linux) — rpi-6.18.y Branch
- Config-Basis: [LibreELEC.tv/projects/RPi/devices/RPi5/linux/linux.aarch64.conf](https://github.com/LibreELEC/LibreELEC.tv/blob/master/projects/RPi/devices/RPi5/linux/linux.aarch64.conf)
- Target: LE13 nightly (Commit `e165a3e0c5c6729d077c30c6d720c029d688d99d` = 6.18.32)
