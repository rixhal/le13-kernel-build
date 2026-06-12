#!/bin/bash
# build.sh — RPi5 Kernel build for LE13 Widevine fix
# Bakes le13-defconfig + DMABUF_HEAPS_RESERVED=y

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL_DIR="$SCRIPT_DIR/kernel-src"
BUILD_DIR="$SCRIPT_DIR/build-output"
CONFIG_BASE="$SCRIPT_DIR/config/le13-defconfig.txt"
CONFIG_DELTA="$SCRIPT_DIR/config/delta-reserved-heap.fragment"

# Requirements check
if [ ! -d "$KERNEL_DIR/Makefile" ]; then
    echo "ERROR: Kernel source not found. Run ./pull-source.sh first."
    exit 1
fi

# Check for compiler (native aarch64 on Pi)
if ! gcc --version &>/dev/null; then
    echo "ERROR: gcc not found"
    exit 1
fi
echo "=== Compiler: $(gcc --version | head -1) ==="

# Prepare config
echo "=== Preparing kernel config ==="
echo "    Base:   $CONFIG_BASE"
echo "    Delta:  $CONFIG_DELTA"
mkdir -p "$BUILD_DIR"

# Merge configs
cp "$CONFIG_BASE" "$KERNEL_DIR/.config"
cat "$CONFIG_DELTA" >> "$KERNEL_DIR/.config"

# Let kbuild resolve dependencies
cd "$KERNEL_DIR"
make olddefconfig ARCH=arm64 2>&1 | tail -1

# Verify our flag stuck
if ! grep -q "CONFIG_DMABUF_HEAPS_RESERVED=y" .config; then
    echo "ERROR: CONFIG_DMABUF_HEAPS_RESERVED not set in final config!"
    echo "Config resolution removed our flag. Check dependencies."
    grep "DMABUF_HEAPS" .config
    exit 1
fi

echo "=== DMABUF_HEAPS in final config ==="
grep "DMABUF_HEAPS" .config

# Build
echo "=== Building kernel (this takes ~45-90 min on Pi 4) ==="
make -j$(nproc) Image.gz modules dtbs ARCH=arm64 2>&1 | tail -5

# Package
echo "=== Packaging kernel.img ==="
KERNEL_IMG="$BUILD_DIR/kernel.img"
if [ -f arch/arm64/boot/Image.gz ]; then
    cp arch/arm64/boot/Image.gz "$KERNEL_IMG.gz"
    gunzip -f "$KERNEL_IMG.gz"
    echo "    Created: $KERNEL_IMG ($(du -h "$KERNEL_IMG" | cut -f1))"
else
    if [ -f arch/arm64/boot/Image ]; then
        cp arch/arm64/boot/Image "$KERNEL_IMG"
        echo "    Created: $KERNEL_IMG ($(du -h "$KERNEL_IMG" | cut -f1))"
    else
        echo "ERROR: No kernel Image found!"
        exit 1
    fi
fi

# Save build manifest
echo "=== Build manifest ==="
{
    echo "Build date: $(date -Iseconds)"
    echo "Kernel commit: $(git log --oneline -1)"
    echo "Config base: $(wc -l < "$CONFIG_BASE") lines"
    echo "Config delta: $CONFIG_DELTA"
    echo "Compiler: $(gcc --version | head -1)"
    echo "Host: $(uname -a)"
    echo "DMABUF_HEAPS:"
    grep "DMABUF_HEAPS" .config
} > "$BUILD_DIR/BUILD_INFO.txt"

cat "$BUILD_DIR/BUILD_INFO.txt"
echo ""
echo "=== Build complete ==="
echo "kernel.img: $KERNEL_IMG"
echo ""
echo "Deploy:"
echo "  scp $KERNEL_IMG root@10.10.10.140:/storage/"
echo "  ssh root@10.10.10.140 'mount -o remount,rw /flash && cp /storage/kernel.img /flash/ && sync && mount -o remount,ro /flash'"
echo "  ssh root@10.10.10.140 'echo b > /proc/sysrq-trigger'"
echo ""
echo "Verify after reboot:"
echo "  ssh root@10.10.10.140 'modprobe configs; zcat /proc/config.gz | grep DMABUF_HEAPS_RESERVED'"
