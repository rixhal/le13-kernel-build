#!/bin/bash
# WLAN Config Extractor - lädt WLAN-Daten aus Kodi-Backups
# Lädt guisettings.xml und sucht nach Network-Settings

BACKUP_FILE="/root/kodi-backup-2026-04-15/config/guisettings.xml"
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

echo "=== WLAN Configuration Extractor ==="

if [ -f "\" ]; then
    echo "✓ Backup-Konfiguration gefunden"
    
    # Suche nach Network-Settings in guisettings.xml
    echo "Extrahiere WLAN-Netzwerke aus Backup..."
    
    # Erstelle Standard-wpa_supplicant mit Backup-Daten
    cat > "\" << 'WPACONF'
country=DE
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
pmf=1

WPACONF
    
    # Versuche SSID aus Backup zu extrahieren (falls in Settings gespeichert)
    SSID=\
    if [ -n "\" ]; then
        echo "Primäres Netzwerk erkannt"
        cat >> "\" << 'WPACONF'
network={
    scan_ssid=1
    key_mgmt=WPA-PSK
    proto=WPA2
    pairwise=CCMP
    priority=5
}

WPACONF
    else
        # Fallback: Nutze Standard Gaming-AP Config + ein offenes Netzwerk zum Setup
        cat >> "\" << 'WPACONF'
# Primäres Netzwerk (Anfangs-Setup)
network={
    ssid="GAMING-AP-MAIN"
    psk="GamingAP2026!"
    key_mgmt=WPA-PSK
    proto=WPA2
    pairwise=CCMP
    priority=5
}

# Alternative (Hotspot)
network={
    ssid="Hotspot-Gaming"
    psk="Gaming2026#"
    key_mgmt=WPA-PSK
    priority=3
}

WPACONF
        echo "Standard Gaming-AP Defaults verwendet"
    fi
    
    echo "✓ wpa_supplicant.conf aktualisiert"
    systemctl restart wpa_supplicant
    echo "✓ WLAN neu gestartet"
else
    echo "✗ Backup nicht gefunden - nutze Standard-Konfiguration"
fi

# Zeige WLAN-Status
echo ""
echo "WLAN Status nach Konfiguration:"
iwconfig 2>/dev/null || echo "iwconfig nicht verfügbar"
echo "IP Address: \"
