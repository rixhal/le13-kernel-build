#!/bin/bash
# WLAN Configuration Extractor from Old Pi Backup
# Versucht WLAN-Daten vom alten Pi zu laden oder fragt den Benutzer

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   WLAN Configuration Setup - From Backup                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
OLD_PI_IP="10.10.10.135"
BACKUP_PATH="/home/richal/kodi-backup-2026-04-15"

echo "[1] Attempting to extract WLAN from old Pi backup..."
echo ""

# Versuche SSH zum alten Pi
if ping -c 1 -W 2 "$OLD_PI_IP" >/dev/null 2>&1; then
    echo "  ✓ Old Pi found at $OLD_PI_IP"

    # Versuche guisettings.xml zu laden
    if ssh -o ConnectTimeout=2 richal@$OLD_PI_IP "test -f ~/.kodi/userdata/guisettings.xml" >/dev/null 2>&1; then
        echo "  ✓ Found guisettings.xml"

        # Extrahiere WLAN-Netzwerke
        echo "  Extracting WLAN networks..."

        # Lade IP-Konfiguration
        OLD_IP=$(ssh richal@$OLD_PI_IP "hostname -I 2>/dev/null | awk '{print \$1}'" 2>/dev/null)
        OLD_HOSTNAME=$(ssh richal@$OLD_PI_IP "hostname 2>/dev/null" 2>/dev/null)

        if [ -n "$OLD_IP" ]; then
            echo "    Old Pi IP: $OLD_IP"
        fi
        if [ -n "$OLD_HOSTNAME" ]; then
            echo "    Hostname: $OLD_HOSTNAME"
        fi

        echo ""
        echo "  To manually extract WLAN password, use:"
        echo "    ssh richal@$OLD_PI_IP"
        echo "    grep -o '<setting.*network.*>' ~/.kodi/userdata/guisettings.xml"
        echo ""
    fi
else
    echo "  ✗ Old Pi not reachable at $OLD_PI_IP"
fi

echo "[2] Manual WLAN Configuration"
echo ""
echo "Since automatic extraction is complex, please provide your WLAN details:"
echo ""
read -p "Enter your WLAN SSID (network name): " SSID
read -sp "Enter your WLAN Password: " PSK
echo ""

if [ -z "$SSID" ] || [ -z "$PSK" ]; then
    echo "Using default Gaming-AP configuration..."
    SSID="GAMING-AP-MAIN"
    PSK="GamingAP2026!"
fi

# Schreibe wpa_supplicant.conf
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

# Fallback
network={
    ssid="GAMING-AP-MAIN"
    psk="GamingAP2026!"
    key_mgmt=WPA-PSK
    priority=1
}
EOF

echo ""
echo "[3] Restarting WiFi..."
systemctl restart wpa_supplicant 2>/dev/null
systemctl restart networking 2>/dev/null
sleep 2

# Test Verbindung
echo ""
echo "[4] Testing connection..."
WLAN_STATUS=$(iwconfig 2>/dev/null | grep -o 'SSID:.*')
if [ -n "$WLAN_STATUS" ]; then
    echo "  ✓ $WLAN_STATUS"
else
    echo "  ℹ Waiting for WiFi connection..."
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✓ WLAN Configuration Complete"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "SSID: $SSID"
echo "Your WiFi should now be connected!"
echo ""
