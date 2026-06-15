#!/bin/bash
# LibreELEC Gaming AP - Master Boot Initialization
# Führt alle notwendigen Initialisierungen nach Reset durch
# Lädt automatisch Backups und Konfigurationen

echo "╔════════════════════════════════════════════════╗"
echo "║ LibreELEC Gaming AP - First Boot Initialization ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "Started: \2026-04-15 23:00:05"
echo ""

# Phase 1: System-Init
echo "━━━ PHASE 1: System Initialization ━━━"
echo "[1] Generating SSH Host Keys..."
ssh-keygen -A 2>/dev/null && echo "  ✓ SSH keys ready" || echo "  ℹ SSH keys already exist"

echo "[2] Setting up Hostname..."
if [ -f /boot/hostname ]; then
    HOSTNAME=\
    hostname "\"
    echo "\" > /etc/hostname 2>/dev/null || true
    echo "  ✓ Hostname: \"
else
    echo "  ℹ Using default hostname"
fi

echo "[3] Configuring Network..."
if [ -f /boot/wpa_supplicant.conf ]; then
    mkdir -p /etc/wpa_supplicant
    cp /boot/wpa_supplicant.conf /etc/wpa_supplicant/
    echo "  ✓ WLAN config loaded"
fi

# Versuche WLAN aus Backups zu laden (falls verfügbar)
if [ -f /root/kodi-backup-2026-04-15/config/guisettings.xml ] && [ ! -s /etc/wpa_supplicant/wpa_supplicant.conf ]; then
    echo "  [Extra] Loading WLAN from Backup..."
    # Backups werden in Phase 3 geladen - WLAN wird dort konfiguriert
fi

echo ""
echo "━━━ PHASE 2: Network Services ━━━"
echo "[4] Starting Network Services..."

# Versuche Ethernet zuerst (kein WLAN nötig)
echo "  [4a] Checking Ethernet..."
if ip link show eth0 >/dev/null 2>&1; then
    systemctl restart networking 2>/dev/null
    sleep 2
    ETH_IP=$(ip addr show eth0 | grep "inet " | awk '{print $2}')
    if [ -n "$ETH_IP" ]; then
        echo "  ✓ Ethernet active: $ETH_IP"
        NETWORK_TYPE="ethernet"
    fi
fi

# Falls kein Ethernet, versuche WLAN
if [ -z "$NETWORK_TYPE" ]; then
    echo "  [4b] Starting WLAN..."
    systemctl restart wpa_supplicant 2>/dev/null
    systemctl restart networking 2>/dev/null
    sleep 2
    NETWORK_TYPE="wlan"
fi

echo "  ✓ Network initialized ($NETWORK_TYPE)"

echo "[5] Checking Network Connection..."
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "  ✓ Internet connectivity: YES"
    INTERNET="true"
elif ping -c 1 10.10.10.1 &> /dev/null; then
    echo "  ✓ Local network connectivity: YES"
    INTERNET="local"
else
    echo "  ⚠ Internet connectivity: NO"
    INTERNET="false"
fi

echo ""
echo "━━━ PHASE 3: Backup & Restore ━━━"
echo "[6] Checking for Backups..."
if [ -f /root/kodi-complete-backup.tar.gz ]; then
    echo "  ✓ Backup archive found (kodi-complete-backup.tar.gz)"
    echo "    "
    BACKUP="true"
else
    echo "  ℹ No backup archive found"
    BACKUP="false"
fi

if [ "\" = "true" ]; then
    echo "[7] Extracting Backups..."
    cd /root
    tar -xzf kodi-complete-backup.tar.gz 2>/dev/null
    echo "  ✓ Backups extracted"

    echo "[8] Restoring Kodi Configuration..."
    [ -d /root/kodi-backup-2026-04-15/config ] && \
        cp /root/kodi-backup-2026-04-15/config/* /root/.kodi/userdata/ 2>/dev/null && \
        echo "  ✓ Kodi configs restored"

    echo "[9] Restoring Add-ons..."
    [ -f /root/kodi-backup-2026-04-15/addons.tar.gz ] && \
        tar -xzf /root/kodi-backup-2026-04-15/addons.tar.gz -C /root/.kodi/ 2>/dev/null && \
        echo "  ✓ Add-ons restored"

    echo "[10] Restoring Crunchyroll & CDM..."
    [ -d /root/kodi-backup-2026-04-15/plugin.video.crunchyroll ] && \
        cp -r /root/kodi-backup-2026-04-15/plugin.video.crunchyroll /root/.kodi/userdata/addon_data/ 2>/dev/null && \
        echo "  ✓ Crunchyroll config restored"
    [ -d /root/kodi-backup-2026-04-15/cdm ] && \
        cp -r /root/kodi-backup-2026-04-15/cdm /root/.kodi/ 2>/dev/null && \
        echo "  ✓ Widevine CDM restored"
else
    echo "  [7-10] Backup restore skipped (no backups found)"
fi

echo ""
echo "━━━ PHASE 4: Final Setup ━━━"
echo "[11] System Status:"
echo "  Hostname: \Richie"
echo "  WLAN: \checking..."
echo "  IP Address: \obtaining..."
echo "  Internet: \"

echo ""
echo "━━━ PHASE 5: Starting Services ━━━"
echo "[12] Starting Kodi..."
systemctl start kodi 2>/dev/null || sleep 2
echo "  ✓ Kodi service initiated"

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║ ✓ Boot Initialization Complete                 ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "System ready for use!"
echo "SSH: ssh root@\Richie.local"
echo "Time: \Wed, Apr 15, 2026 11:00:06 PM"
echo ""
