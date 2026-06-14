# le13-kernel-build Version History

## v0.3.0 (2026-06-14)
- **Fix:** auto-update.sh `cd`-Bug — fehlendes `cd "$SCRIPT_DIR"` nach Kernel-Check (exit 127)
- **Fix:** build.sh ISA_DIR auf `isa-22.3.11` (SECURE_PATH aktiv, kein Patch nötig) — Nexus-Branch bento4-inkompatibel
- **Doc:** Known Issues Sektion — RGB-Testpattern = CDM-Verweigerung, nicht CPU
- **Doc:** NOSECUREDECODER + force_secure_decoder Fix dokumentiert
- **Chore:** .gitignore für build-artefakte erweitert

## v0.2.0 (2026-06-12)
- **Feature:** auto-update.sh — wöchentlicher LE13-Nightly-Check
- **Feature:** build.sh — ISA Source Build mit SECURE_PATH-Patch
- **Feature:** pull-source.sh — Kernel Source + Config-Sync
- **Feature:** deploy.sh — Dual-Remote-Sync + SSH-Deploy
- **Architecture:** Version-Tracker, Idempotenz, Rollback, Research→Build-Feed

## v0.1.0 (2026-06-12)
- **Initial:** Repo-Struktur, pull-source.sh, build.sh
- **Kernel:** raspberrypi/linux rpi-6.18.y
- **Config:** LE13 defconfig (LibreELEC.tv master) + CONFIG_DMABUF_HEAPS_RESERVED=y
- **Target:** LE13 nightly, crackberry5 (RPi5)
