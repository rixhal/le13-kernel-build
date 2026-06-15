#!/bin/bash
# LibreELEC Recovery & Init Script
# Wird nach Reset beim ersten Boot ausgeführt

echo "=== LibreELEC Gaming AP - First Boot Recovery ==="
echo "Timestamp: \Wed, Apr 15, 2026 10:58:28 PM"

# 1. SSH-Keys regenerieren
echo "[1/5] Generating SSH keys..."
ssh-keygen -A 2>/dev/null || echo "SSH keys already present"

# 2. WLAN konfigurieren
echo "[2/5] Configuring WiFi from wpa_supplicant.conf..."
if [ -f /boot/wpa_supplicant.conf ]; then
    cp /boot/wpa_supplicant.conf /etc/wpa_supplicant/ || true
fi

# 3. Hostname setzen
echo "[3/5] Setting hostname..."
if [ -f /boot/hostname ]; then
    HOSTNAME=\
    hostname "\"
    echo "\" > /etc/hostname
fi

# 4. WLAN aktivieren
echo "[4/5] Starting WiFi..."
systemctl restart wpa_supplicant
systemctl restart networking
sleep 3

# 5. Status anzeigen
echo "[5/5] Boot complete!"
echo ""
echo "Network Status:"
ip addr show | grep -E "inet |link"
echo ""
echo "=== Ready for SSH ==="
