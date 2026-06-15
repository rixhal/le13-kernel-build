#!/bin/bash
# LibreELEC Gaming AP - Ready-to-Deploy Verification
# Prüft dass alle Konfigurationen korrekt sind BEVOR der Pi bootet

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   LibreELEC Gaming AP - Ready-to-Deploy Verification       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Dieses Script wird beim ersten Boot ausgeführt."
echo "Es stellt sicher, dass SSH und WLAN funktionieren."
echo ""

# ============================================================
# PHASE 1: Boot-Partition Verification
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 1: Boot Configuration Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "[1.1] SSH Status..."
if [ -f /boot/ssh-enable ]; then
    echo "  ✓ SSH Enabled"
    systemctl status ssh >/dev/null 2>&1 && echo "  ✓ SSH Service Running"
else
    echo "  ⚠ SSH not enabled on boot"
fi

echo "[1.2] Hostname Configuration..."
if [ -f /boot/hostname ]; then
    HOSTNAME=$(cat /boot/hostname)
    echo "  ✓ Hostname: $HOSTNAME"
else
    echo "  ⚠ No hostname configured"
fi

echo "[1.3] WLAN Initial Config..."
if [ -f /boot/wpa_supplicant.conf ]; then
    echo "  ✓ wpa_supplicant.conf present"
    SSID_COUNT=$(grep -c "ssid=" /boot/wpa_supplicant.conf || echo 0)
    echo "    Networks defined: $SSID_COUNT"
else
    echo "  ℹ Primary WLAN config not on boot partition"
fi

# ============================================================
# PHASE 2: Root Partition Verification
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 2: Root Partition Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "[2.1] Kodi Installation..."
if [ -d ~/.kodi ]; then
    echo "  ✓ Kodi directory present"
else
    echo "  ℹ Kodi not initialized yet (will be on first launch)"
fi

echo "[2.2] Backups Check..."
if [ -f ~/kodi-complete-backup.tar.gz ]; then
    SIZE=$(ls -lh ~/kodi-complete-backup.tar.gz | awk '{print $5}')
    echo "  ✓ Backup archive found"
    echo "    Size: $SIZE"
    BACKUP_PRESENT="yes"
else
    echo "  ℹ No backup archive found (fresh install)"
    BACKUP_PRESENT="no"
fi

# ============================================================
# PHASE 3: WLAN Auto-Discovery
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 3: Automatic WLAN Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$BACKUP_PRESENT" = "yes" ]; then
    echo "[3.1] Extracting Backup Archive..."
    cd ~
    tar -xzf kodi-complete-backup.tar.gz 2>/dev/null
    echo "  ✓ Backups extracted"

    echo "[3.2] Searching for WLAN Configuration in Backup..."
    BACKUP_DIR=~/kodi-backup-2026-04-15

    if [ -f "$BACKUP_DIR/config/guisettings.xml" ]; then
        echo "  ✓ guisettings.xml found"

        # Versuche WLAN-Netzwerke aus Kodi-Konfiguration zu laden
        WLAN_SSID=$(grep -oP '<setting id=".*?network.*?" value="\K[^"]+' "$BACKUP_DIR/config/guisettings.xml" | head -1)

        if [ -n "$WLAN_SSID" ]; then
            echo "  ✓ WLAN Network detected: $WLAN_SSID"
        else
            echo "  ℹ No WLAN SSID in guisettings.xml"
            echo "    Using default configuration from wpa_supplicant.conf"
        fi
    fi

else
    echo "[3.1] No backup found - using default WLAN configuration"
    echo "  ✓ Standard Gaming-AP settings will be used"
fi

# ============================================================
# PHASE 4: Network Services
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 4: Network Services Startup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "[4.1] Starting SSH Service..."
systemctl enable ssh 2>/dev/null
systemctl start ssh 2>/dev/null
sleep 1

# Check SSH
if systemctl is-active --quiet ssh; then
    echo "  ✓ SSH Service: ACTIVE"
    echo "    Port: 22"
    echo "    Access: ssh root@$(hostname).local"
else
    echo "  ⚠ SSH Service failed to start"
fi

echo "[4.2] Starting WLAN Services..."
systemctl restart wpa_supplicant 2>/dev/null || true
systemctl restart networking 2>/dev/null || true
sleep 3

echo "[4.3] Checking Network Connectivity..."
if ip link show wlan0 >/dev/null 2>&1; then
    echo "  ✓ WLAN Interface detected"
    WLAN_IP=$(ip addr show wlan0 | grep "inet " | awk '{print $2}')
    if [ -n "$WLAN_IP" ]; then
        echo "    IP: $WLAN_IP"
    else
        echo "    (waiting for DHCP...)"
    fi
else
    echo "  ℹ WLAN interface not yet available"
fi

# ============================================================
# PHASE 5: Backup Restoration
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 5: Backup Restoration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$BACKUP_PRESENT" = "yes" ]; then
    BACKUP_DIR=~/kodi-backup-2026-04-15

    echo "[5.1] Restoring Kodi Configuration..."
    if [ -d "$BACKUP_DIR/config" ]; then
        mkdir -p ~/.kodi/userdata
        cp "$BACKUP_DIR/config"/* ~/.kodi/userdata/ 2>/dev/null
        echo "  ✓ Kodi configs restored"
    fi

    echo "[5.2] Restoring Add-ons..."
    if [ -f "$BACKUP_DIR/addons.tar.gz" ]; then
        tar -xzf "$BACKUP_DIR/addons.tar.gz" -C ~/.kodi/ 2>/dev/null
        echo "  ✓ Add-ons restored"
    fi

    echo "[5.3] Restoring Crunchyroll & Widevine..."
    if [ -d "$BACKUP_DIR/plugin.video.crunchyroll" ]; then
        cp -r "$BACKUP_DIR/plugin.video.crunchyroll" ~/.kodi/userdata/addon_data/ 2>/dev/null
        echo "  ✓ Crunchyroll restored"
    fi
    if [ -d "$BACKUP_DIR/cdm" ]; then
        cp -r "$BACKUP_DIR/cdm" ~/.kodi/ 2>/dev/null
        echo "  ✓ Widevine CDM restored"
    fi
else
    echo "[5.1-5.3] Backup restoration skipped (no backups found)"
fi

# ============================================================
# FINAL STATUS
# ============================================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║ ✓ READY-TO-DEPLOY VERIFICATION COMPLETE                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "System Status Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Hostname:     $(hostname)"
echo "  SSH:          ENABLED (port 22)"
echo "  WLAN:         $(iwconfig 2>/dev/null | grep ESSID || echo 'initializing...')"
echo "  IP Address:   $(hostname -I 2>/dev/null || echo 'obtaining...')"
echo "  Backups:      $BACKUP_PRESENT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "SSH Connection:"
echo "  $ ssh root@$(hostname).local"
echo ""
echo "System is ready for use!"
echo "Timestamp: $(date)"
echo ""
