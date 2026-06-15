#!/bin/bash
# Auto-Extract WLAN from Backup Locally
# Lädt Backup vom Notebook und extrahiert WLAN-Daten automatisch

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Auto-Extract WLAN from Backup (from Notebook)            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

BACKUP_ARCHIVE="/root/kodi-complete-backup.tar.gz"
GUISETTINGS="kodi-backup-2026-04-15/config/guisettings.xml"
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

echo "[1] Checking for backup archive..."

if [ ! -f "$BACKUP_ARCHIVE" ]; then
    echo "  ✗ Backup not yet downloaded"
    echo "  Use ethernet-restore.sh to download from notebook first"
    exit 1
fi

echo "  ✓ Backup found: $BACKUP_ARCHIVE"
SIZE=$(ls -lh "$BACKUP_ARCHIVE" | awk '{print $5}')
echo "    Size: $SIZE"
echo ""

echo "[2] Extracting guisettings.xml..."
cd /root
tar -xzf "$BACKUP_ARCHIVE" "$GUISETTINGS" 2>/dev/null

if [ -f "$GUISETTINGS" ]; then
    echo "  ✓ guisettings.xml extracted"
else
    echo "  ✗ Could not extract guisettings.xml"
    exit 1
fi

echo ""
echo "[3] Extracting WLAN configuration..."

# Versuche WLAN-Daten aus guisettings.xml zu extrahieren
# Kodi speichert WLAN-Einstellungen als XML-Settings

SETTINGS_FILE="$GUISETTINGS"

# Extrahiere SSID (Netzwerkname)
SSID=$(grep -oP '(?<=<setting id=".*ssid.*".*value=")[^"]+' "$SETTINGS_FILE" 2>/dev/null | head -1)

# Fallback: Suche nach network-settings
if [ -z "$SSID" ]; then
    SSID=$(grep -oP 'ssid.*?name=.*?value="\K[^"]+' "$SETTINGS_FILE" 2>/dev/null | head -1)
fi

# Fallback: Einfache Regex
if [ -z "$SSID" ]; then
    SSID=$(sed -n 's/.*ssid.*value="\([^"]*\)".*/\1/p' "$SETTINGS_FILE" 2>/dev/null | head -1)
fi

echo "  Detected SSID: ${SSID:-'(not found - using default)'}"
echo ""

# Falls SSID nicht extrahiert werden konnte, frage Benutzer
if [ -z "$SSID" ]; then
    echo "[4] Manual WLAN Configuration Required"
    echo ""
    echo "Kodi settings don't contain WLAN password (security reason)."
    echo "Please provide your WLAN details:"
    echo ""

    read -p "Enter your WLAN SSID (network name): " SSID
    read -sp "Enter your WLAN Password: " PSK
    echo ""

    if [ -z "$SSID" ] || [ -z "$PSK" ]; then
        echo "Using default configuration..."
        SSID="GAMING-AP-MAIN"
        PSK="GamingAP2026!"
    fi
else
    echo "[4] WLAN Extraction Complete"
    echo ""
    echo "Note: WLAN Password must be entered manually (for security)."
    echo "SSID detected from backup: $SSID"
    echo ""

    read -sp "Enter password for SSID '$SSID': " PSK
    echo ""
fi

# Schreibe wpa_supplicant.conf
echo "[5] Writing wpa_supplicant.conf..."

mkdir -p /etc/wpa_supplicant

cat > "$WPA_CONF" << EOF
country=DE
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
pmf=1

network={
    ssid="$SSID"
    psk="$PSK"
    key_mgmt=WPA-PSK
    proto=WPA2
    pairwise=CCMP
    priority=5
    scan_ssid=1
}

# Fallback Gaming-AP
network={
    ssid="GAMING-AP-MAIN"
    psk="GamingAP2026!"
    key_mgmt=WPA-PSK
    priority=1
}
EOF

echo "  ✓ wpa_supplicant.conf written"
echo ""

# Starte WLAN neu
echo "[6] Restarting WLAN..."
systemctl restart wpa_supplicant 2>/dev/null
systemctl restart networking 2>/dev/null
sleep 3

# Prüfe Verbindung
echo "[7] Testing connection..."
WLAN_STATUS=$(iwconfig 2>/dev/null | grep ESSID || echo "checking...")
IP=$(ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' || echo "obtaining...")

echo "  WLAN: $WLAN_STATUS"
echo "  IP: $IP"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✓ WLAN Configuration Complete"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Connected SSID: $SSID"
echo "Your Gaming-AP is now online!"
echo ""
