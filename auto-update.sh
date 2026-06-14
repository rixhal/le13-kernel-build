#!/bin/bash
# auto-update.sh — Wöchentlicher LE13-Nightly-Check
# Prüft ob es neue LE13-Nightlies oder Kernel-Commits gibt
# Pattern: Cron-Auto-Pull → notify only on changes

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== LE13 Kernel Auto-Update Check ==="
echo ""

# 1. Check LE13 nightly version
echo "[1/3] Checking LE13 nightly..."
INDEX_URL="https://test.libreelec.tv/13.0/RPi/RPi5/"
LATEST_NIGHTLY=$(curl -sL "$INDEX_URL" | grep -oP 'nightly-\d{8}-[a-f0-9]+\.img\.gz' | sort -V | tail -1)
echo "       Latest: $LATEST_NIGHTLY"

# Read last known nightly
LAST_FILE="$SCRIPT_DIR/build-output/.last-nightly"
if [ -f "$LAST_FILE" ]; then
    LAST_NIGHTLY=$(cat "$LAST_FILE")
    echo "       Last:   $LAST_NIGHTLY"
    if [ "$LATEST_NIGHTLY" = "$LAST_NIGHTLY" ]; then
        echo "       → No new nightly"
        NEW_NIGHTLY=false
    else
        echo "       → NEW NIGHTLY AVAILABLE!"
        NEW_NIGHTLY=true
    fi
else
    echo "       (first check — will build)"
    NEW_NIGHTLY=true
fi

# 2. Check kernel source for new commits
echo "[2/3] Checking kernel source..."
if [ -d "$SCRIPT_DIR/kernel-src/.git" ]; then
    cd "$SCRIPT_DIR/kernel-src"
    LOCAL_COMMIT=$(git log --oneline -1)
    git fetch origin rpi-6.18.y --depth 1 2>/dev/null
    REMOTE_COMMIT=$(git log origin/rpi-6.18.y --oneline -1)
    echo "       Local:  $LOCAL_COMMIT"
    echo "       Remote: $REMOTE_COMMIT"
    if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
        echo "       → No new kernel commits"
        NEW_KERNEL=false
    else
        echo "       → NEW KERNEL COMMITS!"
        NEW_KERNEL=true
    fi
else
    echo "       (no kernel source yet — needs pull-source.sh)"
    NEW_KERNEL=true
fi

# Return to repo root after kernel-src cd
cd "$SCRIPT_DIR"

# 3. Check LE13 defconfig for changes
echo "[3/3] Checking LE13 defconfig..."
CONFIG_URL="https://raw.githubusercontent.com/LibreELEC/LibreELEC.tv/master/projects/RPi/devices/RPi5/linux/linux.aarch64.conf"
NEW_CONFIG=$(curl -sL "$CONFIG_URL" | md5sum | cut -d' ' -f1)
if [ -f "$SCRIPT_DIR/config/le13-defconfig.txt" ]; then
    OLD_CONFIG=$(md5sum "$SCRIPT_DIR/config/le13-defconfig.txt" | cut -d' ' -f1)
    echo "       Remote: $NEW_CONFIG"
    echo "       Local:  $OLD_CONFIG"
    if [ "$NEW_CONFIG" = "$OLD_CONFIG" ]; then
        echo "       → No config changes"
        NEW_CONFIG_CHANGED=false
    else
        echo "       → CONFIG CHANGED UPSTREAM!"
        NEW_CONFIG_CHANGED=true
    fi
else
    NEW_CONFIG_CHANGED=true
fi

# 4. Decide: build or skip
echo ""
if $NEW_NIGHTLY || $NEW_KERNEL || $NEW_CONFIG_CHANGED; then
    echo "=== CHANGES DETECTED — triggering rebuild ==="
    echo ""
    echo "Changes:"
    $NEW_NIGHTLY && echo "  • New LE13 nightly: $LATEST_NIGHTLY"
    $NEW_KERNEL && echo "  • New kernel commits"
    $NEW_CONFIG_CHANGED && echo "  • Upstream defconfig changed"
    echo ""

    # Update tracking
    echo "$LATEST_NIGHTLY" > "$LAST_FILE"

    # Run the pipeline
    echo "→ ./pull-source.sh"
    ./pull-source.sh

    echo ""
    echo "→ ./build.sh"
    ./build.sh

    echo ""
    echo "=== Build complete ==="
    echo "kernel.img in build-output/"
    echo "Run ./deploy.sh to install on crackberry5"

else
    echo "=== NO CHANGES — skipping build ==="
    echo "All components up to date."
fi
