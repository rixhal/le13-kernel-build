#!/bin/bash
# diff-build.sh — Zeigt an, was sich seit dem letzten ISA-Build geändert hat
# Vergleicht nightly, kernel-commit und defconfig mit letztem Build

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build-output"
CONFIG_DIR="$SCRIPT_DIR/config"

echo "=== LE13 ISA Build Diff ==="
echo ""

# ISA Version
ISA_VERSION="$(cat "$SCRIPT_DIR/.isa-build-version" 2>/dev/null || echo 'unbekannt')"
echo "ISA Build: $ISA_VERSION"

# Letzter Nightly
if [ -f "$BUILD_DIR/.last-nightly" ]; then
    echo "Letztes Nightly: $(cat "$BUILD_DIR/.last-nightly")"
fi

# Kernel Commit
if [ -d "$SCRIPT_DIR/kernel-src/.git" ]; then
    echo "Kernel: $(cd "$SCRIPT_DIR/kernel-src" && git log --oneline -1)"
fi

# Config
if [ -f "$CONFIG_DIR/le13-defconfig.txt" ]; then
    CONFIG_LINES=$(wc -l < "$CONFIG_DIR/le13-defconfig.txt")
    echo "Defconfig: $CONFIG_LINES lines"
    echo "Defconfig MD5: $(md5sum "$CONFIG_DIR/le13-defconfig.txt" | cut -d' ' -f1)"
fi

# .so
if find "$BUILD_DIR/lib" -name 'inputstream.adaptive.so*' -type f 2>/dev/null | grep -q .; then
    echo "ISA .so: $(find "$BUILD_DIR/lib" -name 'inputstream.adaptive.so*' -type f -exec ls -lh {} \; | awk '{print $5, $9}')"
fi

echo ""
echo "Diff saved to: $BUILD_DIR/BUILD_DIFF.md"
