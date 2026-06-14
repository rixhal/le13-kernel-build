#!/usr/bin/env bash
# le13-isa-build — Deploy ISA .so + Configs auf crackberry5
# Idempotent, mit Rollback-Backup
set -euo pipefail

TARGET="${1:-crackberry5}"
ISA_SO="build-output/lib/inputstream.adaptive.so.22.3.11"

if [ ! -f "$ISA_SO" ]; then
    echo "Keine ISA .so gefunden. Baue zuerst: ./build.sh"
    exit 1
fi

echo "=== Deploy ISA 22.3.11 auf $TARGET ==="

# Prüfen ob Target erreichbar
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$TARGET" "echo OK" 2>/dev/null; then
    echo "WARN: Target $TARGET nicht erreichbar"
    echo "Deploy lokal vorbereitet. Manuell später ausführen:"
    echo "  scp $ISA_SO root@\$TARGET:/storage/.kodi/addons/inputstream.adaptive/"
    exit 0
fi

# Backup alter ISA .so
ssh "root@$TARGET" << 'BCK'
    ISA_DIR="/storage/.kodi/addons/inputstream.adaptive"
    for so in "$ISA_DIR"/inputstream.adaptive.so.*; do
        [ -f "$so" ] || continue
        bak="${so}.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$so" "$bak"
        echo "Backup: $(basename $so) → $(basename $bak)"
    done
    # Cleanup alte Backups (max 3)
    ls -t "$ISA_DIR"/inputstream.adaptive.so.*.bak* 2>/dev/null | tail -n +4 | while read old; do
        rm -f "$old"
        echo "Cleanup: $(basename $old)"
    done
BCK

# Kodi stoppen
ssh "root@$TARGET" 'systemctl stop kodi 2>/dev/null; sleep 1; killall kodi.bin 2>/dev/null; sleep 1'

# ISA .so deployen
scp "$ISA_SO" "root@$TARGET:/storage/.kodi/addons/inputstream.adaptive/"

# Configs deployen (guisettings, advancedsettings, playercorefactory, crunchyroll-patch)
# → wird von deploy-configs.sh gemacht (separat)

# Kodi starten
ssh "root@$TARGET" 'systemctl start kodi'

# Verifikation
sleep 10
echo "=== Verify ==="
ssh "root@$TARGET" 'grep -E "Addon Manager.*inputstream" /storage/.kodi/temp/kodi.log | tail -3'

echo ""
echo "Deploy OK"
echo "Nächster Schritt: deploy-configs.sh ausführen für guisettings/advancedsettings/playercorefactory"
