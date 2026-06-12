#!/bin/bash
# deploy.sh — Idempotentes Kernel-Deployment auf crackberry5
# Pattern: Version-Tracker, Rollback, Idempotenz

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build-output"
TARGET_HOST="${1:-10.10.10.140}"
TARGET_USER="${2:-root}"
KERNEL_IMG="$BUILD_DIR/kernel.img"
VERSION_FILE="/storage/.le13-kernel-version"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d)"

echo "=== LE13 Kernel Deployer ==="

# 1. Verify kernel.img exists
if [ ! -f "$KERNEL_IMG" ]; then
    echo "ERROR: $KERNEL_IMG not found. Run ./build.sh first."
    exit 1
fi

LOCAL_MD5=$(md5sum "$KERNEL_IMG" | cut -d' ' -f1)
echo "[1/6] Local kernel: $LOCAL_MD5 ($(du -h "$KERNEL_IMG" | cut -f1))"

# 2. Read BUILD_INFO
if [ -f "$BUILD_DIR/BUILD_INFO.txt" ]; then
    BUILD_VERSION=$(grep "Kernel commit:" "$BUILD_DIR/BUILD_INFO.txt" | head -1)
    echo "       $BUILD_VERSION"
fi

# 3. Check target status (idempotency)
echo "[2/6] Checking target at $TARGET_HOST..."
TARGET_INFO=$(ssh "${TARGET_USER}@${TARGET_HOST}" "
    if [ -f $VERSION_FILE ]; then cat $VERSION_FILE; else echo 'NO_VERSION_FILE'; fi
    md5sum /flash/kernel.img 2>/dev/null | cut -d' ' -f1 || echo 'NO_KERNEL'
    uname -r
" 2>&1)

TARGET_VER=$(echo "$TARGET_INFO" | head -1)
TARGET_MD5=$(echo "$TARGET_INFO" | head -2 | tail -1)
TARGET_UNAME=$(echo "$TARGET_INFO" | tail -1)

echo "       Target version: $TARGET_VER"
echo "       Target MD5:     $TARGET_MD5"
echo "       Target uname:   $TARGET_UNAME"

# 4. Idempotenz-Check
if [ "$LOCAL_MD5" = "$TARGET_MD5" ]; then
    echo ""
    echo "=== IDEMPOTENT: Kernel already deployed (MD5 match) ==="
    echo "Target has the same kernel.img. Skipping deployment."
    echo "Run with --force to override."
    [ "${1:-}" = "--force" ] || exit 0
fi

# 5. Backup current kernel (rollback)
echo "[3/6] Backing up current kernel on target..."
ssh "${TARGET_USER}@${TARGET_HOST}" "
    mount -o remount,rw /flash
    if [ -f /flash/kernel.img ]; then
        cp /flash/kernel.img /flash/kernel.img${BACKUP_SUFFIX}
        echo '       Backup: kernel.img${BACKUP_SUFFIX}'
    fi
    # Keep max 3 backups
    ls -t /flash/kernel.img.bak.* 2>/dev/null | tail -n +4 | xargs -r rm
    sync
"

# 6. Deploy
echo "[4/6] Uploading kernel.img ($(du -h "$KERNEL_IMG" | cut -f1))..."
scp "$KERNEL_IMG" "${TARGET_USER}@${TARGET_HOST}:/storage/kernel-widevine.img"

echo "[5/6] Installing to /flash..."
ssh "${TARGET_USER}@${TARGET_HOST}" "
    mount -o remount,rw /flash
    cp /storage/kernel-widevine.img /flash/kernel.img
    sync
    NEW_MD5=\$(md5sum /flash/kernel.img | cut -d' ' -f1)
    echo \"       Deployed MD5: \$NEW_MD5\"
    mount -o remount,ro /flash
"

# 7. Write version marker
echo "[6/6] Writing version marker..."
BUILD_DATE=$(date -Iseconds)
ssh "${TARGET_USER}@${TARGET_HOST}" "
    cat > $VERSION_FILE << 'VEREOF'
Build: $BUILD_DATE
Kernel: $BUILD_VERSION
Config: CONFIG_DMABUF_HEAPS_RESERVED=y
Repo: https://github.com/rixhal/le13-kernel-build
VEREOF
    cat $VERSION_FILE
"

echo ""
echo "=== DEPLOYMENT COMPLETE ==="
echo ""
echo "Rollback:"
echo "  ssh ${TARGET_USER}@${TARGET_HOST} 'mount -o remount,rw /flash && cp /flash/kernel.img${BACKUP_SUFFIX} /flash/kernel.img && sync'"
echo ""
echo "Next: Manual reboot required"
echo "  ssh ${TARGET_USER}@${TARGET_HOST} 'echo b > /proc/sysrq-trigger'"
echo ""
echo "Verify after reboot:"
echo "  ssh ${TARGET_USER}@${TARGET_HOST} 'modprobe configs; zcat /proc/config.gz | grep DMABUF_HEAPS_RESERVED'"
echo "  Expected: CONFIG_DMABUF_HEAPS_RESERVED=y"
