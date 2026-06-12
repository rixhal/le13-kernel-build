#!/bin/bash
# pull-source.sh — RPi5 LE13 kernel source puller
# Clones raspberrypi/linux rpi-6.18.y (shallow, depth=1, ~300 MB)

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL_DIR="$SCRIPT_DIR/kernel-src"

echo "=== LE13 Kernel Source Puller ==="

# 1. Fetch latest defconfig from LE13.tv master
echo "[1/3] Fetching latest LE13 kernel config..."
LE_CONFIG_URL="https://raw.githubusercontent.com/LibreELEC/LibreELEC.tv/master/projects/RPi/devices/RPi5/linux/linux.aarch64.conf"
curl -sL "$LE_CONFIG_URL" -o "$SCRIPT_DIR/config/le13-defconfig.txt"
echo "       $(wc -l < "$SCRIPT_DIR/config/le13-defconfig.txt") lines"

# 2. Check which kernel commit LE13.tv currently uses
echo "[2/3] Checking LE13 kernel version..."
PKG_MK="https://raw.githubusercontent.com/LibreELEC/LibreELEC.tv/master/packages/linux/package.mk"
KERNEL_COMMIT=$(curl -sL "$PKG_MK" | grep -A1 'PKG_VERSION' | tail -1 | grep -oP '[a-f0-9]{40}')
if [ -z "$KERNEL_COMMIT" ]; then
    KERNEL_COMMIT=$(curl -sL "$PKG_MK" | grep -oP '(?<=PKG_VERSION=")[a-f0-9]+(?=")' | tail -1)
fi
echo "       LE13 kernel commit: ${KERNEL_COMMIT:-UNKNOWN}"

# 3. Clone or update source
if [ -d "$KERNEL_DIR/.git" ]; then
    echo "[3/3] Kernel source exists — fetching updates..."
    cd "$KERNEL_DIR"
    git fetch origin rpi-6.18.y --depth 1 2>&1 | tail -1
    if [ -n "$KERNEL_COMMIT" ]; then
        git checkout "$KERNEL_COMMIT" 2>/dev/null || echo "       (staying on rpi-6.18.y HEAD)"
    else
        git checkout FETCH_HEAD
    fi
else
    echo "[3/3] Cloning kernel source (shallow, rpi-6.18.y)..."
    git clone --depth 1 --branch rpi-6.18.y \
        https://github.com/raspberrypi/linux.git "$KERNEL_DIR" 2>&1 | tail -2
    cd "$KERNEL_DIR"
    if [ -n "$KERNEL_COMMIT" ]; then
        echo "       Checking out exact LE13 commit: $KERNEL_COMMIT"
        git fetch origin "$KERNEL_COMMIT" --depth 1 2>&1 | tail -1
        git checkout "$KERNEL_COMMIT"
    fi
fi

echo "       Source: $(git log --oneline -1)"
echo "       Size: $(du -sh . 2>/dev/null | cut -f1)"

# 4. Apply our config
echo ""
echo "=== Kernel source ready ==="
echo "Next: ./build.sh"
