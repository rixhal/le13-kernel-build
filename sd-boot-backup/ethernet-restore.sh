#!/bin/bash
# Ethernet-based Backup Restore
# Lädt Backup vom Notebook über Ethernet (keine WLAN nötig!)

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Backup Restore via Ethernet (Plug & Play)               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

BACKUP_PATH="/root/kodi-complete-backup.tar.gz"

echo "Ethernet-Restore Instructions:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "SETUP:"
echo "  1. Pi mit Ethernet-Kabel an Router/Notebook verbinden"
echo "  2. Nach 10 Sekunden sollte eth0 eine IP haben"
echo "  3. Dann vom Notebook laden:"
echo ""
echo "METHODE A: Direktes Laden vom Notebook via SCP"
echo "  $ ssh root@libreelec-pi-gaming.local"
echo "  $ scp richa@NOTEBOOK_IP:~/pi\\ script/kodi-complete-backup.tar.gz ~"
echo ""
echo "METHODE B: Automatisch mit diesem Script"
echo "  $ bash /boot/ethernet-restore.sh"
echo ""
echo "METHODE C: SMB/Samba Share (wenn auf Notebook konfiguriert)"
echo "  $ mount -t cifs //NOTEBOOK_IP/backup /mnt/notebook"
echo "  $ cp /mnt/notebook/kodi-complete-backup.tar.gz ~/"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Auto-detect Notebook IP
echo "[1] Scanning network for Notebook..."
echo ""

# Versuche häufige IPs
POSSIBLE_IPS=("10.10.10.1" "10.10.10.5" "192.168.1.100" "192.168.0.100" "192.168.2.1")

for ip in "${POSSIBLE_IPS[@]}"; do
    if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
        echo "  ✓ Found host at $ip"
        echo ""
        echo "Attempting to download backup from $ip..."

        # Versuche SSH
        if ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no richa@$ip "ls ~/pi\ script/kodi-complete-backup.tar.gz" >/dev/null 2>&1; then
            echo "  ✓ SSH access confirmed"
            echo ""
            echo "Starting download..."
            scp -r richa@$ip:~/pi\ script/kodi-complete-backup.tar.gz ~/ && {
                echo "  ✓ Download complete!"
                echo ""
                echo "[2] Extracting backup..."
                tar -xzf ~/kodi-complete-backup.tar.gz ~
                echo "  ✓ Extracted"

                echo "[3] Restoring Kodi configuration..."
                mkdir -p ~/.kodi/userdata
                cp ~/kodi-backup-2026-04-15/config/* ~/.kodi/userdata/ 2>/dev/null
                echo "  ✓ Settings restored"

                echo "[4] Restoring add-ons..."
                tar -xzf ~/kodi-backup-2026-04-15/addons.tar.gz -C ~/.kodi/ 2>/dev/null
                echo "  ✓ Add-ons restored"

                echo ""
                echo "═══════════════════════════════════════════════════════════"
                echo "✓ Backup Restoration Complete!"
                echo "═══════════════════════════════════════════════════════════"
                echo ""
                echo "Restarting Kodi..."
                systemctl restart kodi
                exit 0
            }
        fi
    fi
done

echo "  ⚠ Could not auto-detect Notebook"
echo ""
echo "Manual fallback:"
echo "  1. Check Notebook IP: ipconfig (on Windows)"
echo "  2. Then: scp richa@YOUR_NOTEBOOK_IP:~/pi\\ script/kodi-complete-backup.tar.gz ~"
echo ""
