#!/usr/bin/env bash
# le13-isa-build — Rollback: LE12 (Kodi 21) wiederherstellen
# Setzt LE13 auf LE12 zurück, inkl. SYSTEM+kernel+Addon-Settings.
# Voraussetzung: Backup-Dateien existieren auf crackberry5
set -euo pipefail

TARGET="${1:-crackberry5}"

echo "=== Rollback zu LE12 auf $TARGET ==="
echo ""

# Prüfe Target
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$TARGET" "echo OK" 2>/dev/null; then
    echo "FEHLER: $TARGET nicht erreichbar"
    exit 1
fi

echo "--- Schritt 1: LE12-Backups finden ---"
ssh "root@$TARGET" << 'FIND'
    echo "=== LE12 SYSTEM Backups ==="
    find /storage -maxdepth 3 -name 'backup-SYSTEM-le12*' -o -name 'backup-kernel-le12*' | sort
    echo ""
    echo "=== Kodi-Settings Backup ==="
    find /storage -maxdepth 2 -name 'backup-kodi*.tar.gz' | sort
    echo ""
    echo "=== .update Ordner (falls LE12-Tar vorhanden) ==="
    ls -la /storage/.update/ 2>/dev/null || echo "(leer)"
FIND

echo ""
echo "--- Schritt 2: Kodi stoppen ---"
ssh "root@$TARGET" 'systemctl stop kodi 2>/dev/null; sleep 2; killall kodi.bin 2>/dev/null; sleep 2'

echo ""
echo "--- Schritt 3: LE13-Kodi-Settings sichern ---"
ssh "root@$TARGET" 'mkdir -p /storage/rollback-safety/le13-before-rollback'
ssh "root@$TARGET" 'cp /storage/.kodi/temp/kodi.log /storage/rollback-safety/le13-before-rollback/ 2>/dev/null || true'
ssh "root@$TARGET" 'tar -czf /storage/rollback-safety/le13-before-rollback/kodi-addons.tar.gz /storage/.kodi/addons/ 2>/dev/null || true'

echo ""
echo "--- Schritt 4: LE12 SYSTEM + kernel zurückspielen ---"
ssh "root@$TARGET" << 'BOOT'
    SYS_BACKUP=$(find /storage -maxdepth 3 -name 'backup-SYSTEM-le12*' -type f | head -1)
    KERN_BACKUP=$(find /storage -maxdepth 3 -name 'backup-kernel-le12*' -type f | head -1)

    if [ -z "$SYS_BACKUP" ] || [ -z "$KERN_BACKUP" ]; then
        echo "FEHLER: LE12-Backup-Dateien nicht gefunden"
        exit 1
    fi

    echo "SYSTEM: $SYS_BACKUP ($(du -h "$SYS_BACKUP" | cut -f1))"
    echo "Kernel: $KERN_BACKUP ($(du -h "$KERN_BACKUP" | cut -f1))"

    # Backup aktuelle LE13 Boot-Dateien
    cp /flash/SYSTEM /storage/rollback-safety/le13-before-rollback/SYSTEM
    cp /flash/kernel.img /storage/rollback-safety/le13-before-rollback/kernel.img 2>/dev/null || true

    # LE12 zurückspielen
    cp "$SYS_BACKUP" /flash/SYSTEM
    cp "$KERN_BACKUP" /flash/kernel.img 2>/dev/null || true
    sync
    echo "LE12 Boot-Dateien deployed"
BOOT

echo ""
echo "--- Schritt 5: LE12-Kodi-Addon-Settings wiederherstellen ---"
ssh "root@$TARGET" << 'KODI'
    KODI_BAK=$(find /storage -maxdepth 2 -name 'backup-kodi*.tar.gz' -type f | head -1)

    if [ -n "$KODI_BAK" ]; then
        echo "Kodi-Backup gefunden: $KODI_BAK ($(du -h "$KODI_BAK" | cut -f1))"

        # Bestehende Kodi-Daten sichern (nur addons/userdata, nicht cdm)
        mv /storage/.kodi/addons /storage/.kodi/addons.le13 2>/dev/null || true
        mv /storage/.kodi/userdata /storage/.kodi/userdata.le13 2>/dev/null || true

        # LE12 Backup entpacken (enthält addons + userdata)
        tar -xzf "$KODI_BAK" -C /storage/.kodi/ 2>/dev/null || \
        tar -xzf "$KODI_BAK" -C /storage/ 2>/dev/null || \
        echo "WARN: Kodi-Backup konnte nicht entpackt werden — manuelle Wiederherstellung nötig"

        echo "Kodi-Settings wiederhergestellt"
    else
        echo "WARN: Kein Kodi-Backup gefunden — Addons bleiben wie unter LE13"
        echo "Hinweis: Kodi 22 Addons sind oft binärkompatibel mit Kodi 21"
    fi
KODI

echo ""
echo "--- Schritt 6: Widevine-CDM prüfen ---"
ssh "root@$TARGET" << 'CDM'
    WV=$(find /storage/.kodi /storage/.cache -name 'libwidevinecdm.so' 2>/dev/null | head -1)
    if [ -z "$WV" ]; then
        echo "WARN: Kein Widevine-CDM gefunden — wird beim ersten DRM-Start automatisch installiert"
    else
        echo "Widevine-CDM: $WV"
        sha256sum "$WV"
    fi
CDM

echo ""
echo "=== Rollback abgeschlossen ==="
echo "Jetzt: ssh $TARGET 'reboot'"
echo ""
echo "Nach Neustart prüfen:"
echo "  cat /etc/os-release  # Sollte LE12 zeigen"
echo "  cat /storage/.kodi/temp/kodi.log | grep 'inputstream.adaptive' | head -3"
echo ""
echo "Bei Problemen: LE13-Backup liegt in /storage/rollback-safety/le13-before-rollback/"
