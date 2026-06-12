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

# 2. Bauen (nativ auf Pi 4, ~45-90 Minuten)
./build.sh

# 3. Deployen (idempotent, mit Rollback-Backup)
./deploy.sh

# 4. Nach Reboot verifizieren
ssh root@10.10.10.140 "modprobe configs; zcat /proc/config.gz | grep DMABUF_HEAPS_RESERVED"
```

## Architektur-Patterns (aus LE12-Transplant + SMP-Research gelernt)

### 1. Version-Tracker
- `.le13-kernel-version` auf Target → `deploy.sh` prüft vor Deployment
- `CHANGELOG.md` im Repo → menschlich lesbare History

### 2. Idempotenz
- `deploy.sh` vergleicht MD5 von lokalem und Target-kernel.img
- Wenn identisch → skip (außer `--force`)
- Kein redundantes Reboot, kein unnötiges /flash-Schreiben

### 3. Rollback
- Vor jedem Deploy: `cp /flash/kernel.img /flash/kernel.img.bak.YYYYMMDD`
- Max 3 Backups behalten (Auto-Cleanup)
- Rollback-Befehl wird nach Deploy ausgegeben

### 4. Build-Diff
- `diff-build.sh` zeigt: Source-Commit, Config-Änderungen, Delta-Status
- `build-output/CONFIG_DIFF.md` automatisch generiert

### 5. Research→Build-Feed
- `research-patches/` Ordner für .fragment-Dateien aus Widevine-Cron
- `apply-research-patch.sh` merged neue CONFIG_*-Flags ins Delta
- Widevine-Cron (9827948be189) kann per PR/Commit neue Patches einspielen

### 6. Cron-Auto-Pull
- `auto-update.sh` prüft wöchentlich auf:
  - Neue LE13-Nightlies
  - Neue Kernel-Commits (rpi-6.18.y)
  - Defconfig-Änderungen upstream
- Nur bei Änderungen: pull → build → sync (kein Spam)

### 7. Dual-Remote-Sync
- `sync-remotes.sh` nach jedem Build → commit + push beide Remotes
- GitHub: git@github.com:rixhal/le13-kernel-build.git
- Forgejo: https://git.richie.fyi/rixhal/le13-kernel-build.git

## Scripts

| Script | Zweck | Trigger |
|--------|-------|---------|
| `pull-source.sh` | Kernel-Quellen + Defconfig holen | Manuell / auto-update |
| `build.sh` | Kernel bauen | Nach pull-source |
| `deploy.sh` | kernel.img auf crackberry5 | Nach Build |
| `diff-build.sh` | Build-Diff anzeigen | Vor/Nach Build |
| `auto-update.sh` | Auf Änderungen prüfen | Cron (wöchentlich) |
| `apply-research-patch.sh` | Research-Funde einspielen | Nach Widevine-Cron |
| `sync-remotes.sh` | Commit + Push beide Remotes | Nach Änderungen |

## Verfikation

```bash
ssh root@10.10.10.140 "modprobe configs; zcat /proc/config.gz | grep DMABUF_HEAPS_RESERVED"
# Erwartet: CONFIG_DMABUF_HEAPS_RESERVED=y
```

## Source

- Kernel: [raspberrypi/linux](https://github.com/raspberrypi/linux) — rpi-6.18.y Branch
- Config-Basis: [LibreELEC.tv/projects/RPi/devices/RPi5/linux/linux.aarch64.conf](https://github.com/LibreELEC/LibreELEC.tv/blob/master/projects/RPi/devices/RPi5/linux/linux.aarch64.conf)
- Target: LE13 nightly (Commit `e165a3e0c5c6729d077c30c6d720c029d688d99d` = 6.18.32)
