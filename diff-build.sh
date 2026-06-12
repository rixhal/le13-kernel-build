#!/bin/bash
# diff-build.sh — Zeigt an, was sich zwischen letztem und aktuellem Build geändert hat

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build-output"
CONFIG_DIR="$SCRIPT_DIR/config"
DIFF_FILE="$BUILD_DIR/CONFIG_DIFF.md"

echo "=== LE13 Kernel Build Diff ==="
echo ""

# Check if last build exists
LAST_INFO="$BUILD_DIR/BUILD_INFO.txt"
CURRENT_COMMIT=""

if [ -d "$SCRIPT_DIR/kernel-src/.git" ]; then
    CURRENT_COMMIT=$(cd "$SCRIPT_DIR/kernel-src" && git log --oneline -1)
fi

# Config diff
if [ -f "$CONFIG_DIR/le13-defconfig.txt" ]; then
    CONFIG_LINES=$(wc -l < "$CONFIG_DIR/le13-defconfig.txt")
    echo "LE13 Defconfig: $CONFIG_LINES lines"
fi

# DMABUF_HEAPS status
if [ -d "$SCRIPT_DIR/kernel-src" ] && [ -f "$SCRIPT_DIR/kernel-src/.config" ]; then
    echo ""
    echo "=== DMABUF_HEAPS in working config ==="
    grep "DMABUF_HEAPS" "$SCRIPT_DIR/kernel-src/.config" || echo "(no .config yet — run build.sh first)"
fi

# Generate diff markdown
{
    echo "# Kernel Build Diff — $(date -I)"
    echo ""
    echo "## Source"
    echo "- Kernel: $CURRENT_COMMIT"
    echo "- Config base: $CONFIG_LINES lines"
    echo "- Patches applied:"
    cat "$CONFIG_DIR/delta-reserved-heap.fragment"
    echo ""
    echo "## Last build"
    if [ -f "$LAST_INFO" ]; then
        echo '```'
        cat "$LAST_INFO"
        echo '```'
    else
        echo "(no previous build)"
    fi
} > "$DIFF_FILE"

echo ""
echo "Diff saved to: $DIFF_FILE"
cat "$DIFF_FILE"
