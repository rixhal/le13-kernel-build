#!/bin/bash
# Auto-Restore Script für Kodi-Backups nach LibreELEC Boot
# Lädt automatisch die Backups von ~/kodi-complete-backup.tar.gz

echo "=== LibreELEC Auto-Restore Starting ==="
echo "Timestamp: \Wed, Apr 15, 2026 10:59:49 PM"
echo ""

# Check if backups exist
if [ -f ~/kodi-complete-backup.tar.gz ]; then
    echo "[1/4] Backups gefunden: kodi-complete-backup.tar.gz"
    ls -lh ~/kodi-complete-backup.tar.gz
    echo ""
    
    # Backup extrahieren
    echo "[2/4] Extrahiere Backups..."
    tar -xzf ~/kodi-complete-backup.tar.gz -C ~/
    echo "✓ Backups extrahiert"
    echo ""
    
    # Kodi-Userdata restaurieren
    if [ -d ~/kodi-backup-2026-04-15/config ]; then
        echo "[3/4] Restauriere kritische Kodi-Konfiguration..."
        cp ~/kodi-backup-2026-04-15/config/guisettings.xml ~/.kodi/userdata/ 2>/dev/null || true
        cp ~/kodi-backup-2026-04-15/config/advancedsettings.xml ~/.kodi/userdata/ 2>/dev/null || true
        echo "✓ Kodi-Config restauriert"
    fi
    
    # Add-ons restaurieren
    if [ -f ~/kodi-backup-2026-04-15/addons.tar.gz ]; then
        echo "[4/4] Restauriere Add-ons..."
        tar -xzf ~/kodi-backup-2026-04-15/addons.tar.gz -C ~/.kodi/
        echo "✓ Add-ons restauriert"
    fi
    
    # Crunchyroll + CDM restores (falls vorhanden)
    if [ -d ~/kodi-backup-2026-04-15 ]; then
        echo ""
        echo "Spezielle Restores:"
        [ -d ~/kodi-backup-2026-04-15/plugin.video.crunchyroll ] && \
            cp -r ~/kodi-backup-2026-04-15/plugin.video.crunchyroll ~/.kodi/userdata/addon_data/ && \
            echo "  ✓ Crunchyroll-Config"
        [ -d ~/kodi-backup-2026-04-15/cdm ] && \
            cp -r ~/kodi-backup-2026-04-15/cdm ~/.kodi/ && \
            echo "  ✓ Widevine CDM"
    fi
    
    # Restart Kodi für neue Settings
    echo ""
    echo "Starte Kodi neu um Änderungen zu übernehmen..."
    systemctl restart kodi
    echo ""
    echo "=== Auto-Restore Complete ==="
    echo "Kodi sollte jetzt mit allen Einstellungen verfügbar sein."
    
else
    echo "✗ Keine Backups gefunden (~/kodi-complete-backup.tar.gz)"
    echo "  Kodi wird mit Standard-Einstellungen gestartet."
fi
