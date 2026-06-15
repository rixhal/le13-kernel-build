#!/bin/bash
# Smart Configuration Sync nach Reset
# Versucht automatisch die besten Einstellungen zu laden

echo "=== LibreELEC Smart Config Sync ==="

# 1. Versuche WLAN aus Kodi-Backup zu laden (falls vorhanden)
KODI_BACKUP="/root/kodi-backup-2026-04-15"

if [ -d "\" ]; then
    echo "[1/3] Kodi-Backup erkannt"
    
    # Extrahiere WLAN-Infos aus advancedsettings.xml falls vorhanden
    if [ -f "\/config/advancedsettings.xml" ]; then
        echo "[2/3] WLAN-Konfiguration aus Backup laden..."
        cp "\/config/advancedsettings.xml" ~/.kodi/userdata/ 2>/dev/null
        # Die advancedsettings.xml enthält Kodi-spezifische Network-Settings
    fi
    
    # Stelle sicher dass guisettings.xml auch geladen wird
    if [ -f "\/config/guisettings.xml" ]; then
        echo "[3/3] Kodi-GUI-Settings laden..."
        cp "\/config/guisettings.xml" ~/.kodi/userdata/
    fi
    
    echo ""
    echo "✓ Kodi-Settings aus Backup restauriert"
    
else
    echo "✗ Kodi-Backup nicht gefunden"
    echo "  Verwende Standard-Einstellungen"
fi

echo ""
echo "=== Smart Config Sync Complete ==="
