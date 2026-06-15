#!/bin/bash
# MASTER BACKUP RESTORE & WLAN SETUP
# Koordiniert: Download → Extract → WLAN-Config → Kodi-Restore

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     MASTER BACKUP RESTORE (from Notebook)                  ║"
echo "║     Step 1: Download                                       ║"
echo "║     Step 2: Extract WLAN Config                            ║"
echo "║     Step 3: Restore Kodi Settings                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

NOTEBOOK_USER="richa"
NOTEBOOK_IPS=("10.10.10.1" "10.10.10.5" "192.168.1.100" "192.168.0.100" "192.168.1.1")
BACKUP_ARCHIVE="/root/kodi-complete-backup.tar.gz"
WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

# ============================================================
# PHASE 1: Download
# ============================================================
echo "PHASE 1: Downloading Backup from Notebook"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "$BACKUP_ARCHIVE" ]; then
    echo "✓ Backup already downloaded, skipping..."
    echo ""
else
    echo "[1.1] Auto-detecting Notebook..."
    NOTEBOOK_HOST=""

    for ip in "${NOTEBOOK_IPS[@]}"; do
        if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
            echo "  ✓ Found host at $ip"
            NOTEBOOK_HOST="$ip"
            break
        fi
    done

    if [ -z "$NOTEBOOK_HOST" ]; then
        echo "  ⚠ Could not auto-detect Notebook"
        read -p "Enter Notebook IP manually: " NOTEBOOK_HOST
    fi

    echo ""
    echo "[1.2] Downloading backup (this may take 2-5 minutes)..."
    scp -r "$NOTEBOOK_USER@$NOTEBOOK_HOST:~/pi\ script/kodi-complete-backup.tar.gz" ~/ && {
        echo "  ✓ Download complete!"
    } || {
        echo "  ✗ Download failed"
        echo "  Check: SSH access, Notebook IP, file path"
        exit 1
    }
fi

# ============================================================
# PHASE 2: Extract & WLAN Config
# ============================================================
echo ""
echo "PHASE 2: Extracting WLAN Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd /root
echo "[2.1] Extracting guisettings.xml..."

# Extrahiere WLAN-Datei
tar -xzf "$BACKUP_ARCHIVE" "kodi-backup-2026-04-15/config/guisettings.xml" 2>/dev/null

if [ -f "kodi-backup-2026-04-15/config/guisettings.xml" ]; then
    echo "  ✓ guisettings.xml found"

    # Versuche SSID zu detektieren
    GUISETTINGS="kodi-backup-2026-04-15/config/guisettings.xml"
    SSID=$(grep -oP '(?<=ssid.*?value=")[^"]+' "$GUISETTINGS" | head -1)

    if [ -n "$SSID" ]; then
        echo "  ✓ SSID detected: $SSID"
    else
        echo "  ℹ SSID not in guisettings (security)"
    fi
else
    echo "  ✗ guisettings.xml not found in backup"
    SSID=""
fi

echo ""
[2.2] Extracting WLAN from guisettings.xml..."

# Versuche alle Netzwerk-Einstellungen aus guisettings zu laden
if [ -f "$GUISETTINGS" ]; then
    # Extrahiere Network-Namen und IPs aus den alten Settings
    echo "  Searching for saved WLAN configuration..."

    # Versuche IP-Konfiguration zu finden
    OLD_IP=$(grep -oP '(?<=<setting[^>]*network.*ip[^>]*value=")[^"]+' "$GUISETTINGS" | head -1)
    if [ -n "$OLD_IP" ]; then
        echo "  Found previous IP: $OLD_IP"
    fi
fi

echo ""
echo "[2.3] Configuring WLAN..."

if [ -n "$SSID" ]; then
    echo "  Using detected SSID: $SSID"
    read -sp "  Enter WiFi Password for '$SSID': " PSK
    echo ""
else
    echo "  Enter your WiFi details:"
    read -p "  SSID (network name): " SSID
    read -sp "  Password: " PSK
    echo ""
fi

# Fallback zu vorherigen Settings falls vorhanden
if [ -z "$SSID" ] && [ -n "$OLD_IP" ]; then
    echo "  Using previous network configuration"
elif [ -z "$SSID" ]; then
    SSID="crackberry5-wifi"
    PSK="$(hostname)"
    echo "  Using default configuration"
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

network={
    ssid="GAMING-AP-MAIN"
    psk="GamingAP2026!"
    key_mgmt=WPA-PSK
    priority=1
}
EOF

systemctl restart wpa_supplicant 2>/dev/null
systemctl restart networking 2>/dev/null
sleep 2

echo "  ✓ WLAN configured"

# ============================================================
# PHASE 3: Restore
# ============================================================
echo ""
echo "PHASE 3: Restoring Kodi Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "[3.1] Extracting backup archive..."
tar -xzf "$BACKUP_ARCHIVE" 2>/dev/null
echo "  ✓ Extracted"

echo "[3.2] Restoring Kodi settings..."
mkdir -p ~/.kodi/userdata
if [ -d "kodi-backup-2026-04-15/config" ]; then
    cp kodi-backup-2026-04-15/config/* ~/.kodi/userdata/
    echo "  ✓ guisettings.xml & advancedsettings.xml restored"
fi

echo "[3.3] Restoring add-ons..."
if [ -f "kodi-backup-2026-04-15/addons.tar.gz" ]; then
    tar -xzf kodi-backup-2026-04-15/addons.tar.gz -C ~/.kodi/
    echo "  ✓ Add-ons restored"
fi

echo "[3.4] Restoring Crunchyroll & Widevine..."
if [ -d "kodi-backup-2026-04-15/plugin.video.crunchyroll" ]; then
    mkdir -p ~/.kodi/userdata/addon_data
    cp -r kodi-backup-2026-04-15/plugin.video.crunchyroll ~/.kodi/userdata/addon_data/
    echo "  ✓ Crunchyroll restored"
fi
if [ -d "kodi-backup-2026-04-15/cdm" ]; then
    cp -r kodi-backup-2026-04-15/cdm ~/.kodi/
    echo "  ✓ Widevine CDM restored"
fi

# ============================================================
# FINAL
# ============================================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║ ✓ MASTER RESTORE COMPLETE                                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Status:"
echo "  SSID: $SSID"
echo "  Kodi: Ready to start"
echo ""
echo "Restarting Kodi..."
systemctl restart kodi

echo ""
echo "Your Gaming-AP is fully restored! 🎮"
echo ""
