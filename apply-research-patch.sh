#!/bin/bash
# apply-research-patch.sh — Wendet Erkenntnisse aus Widevine-Research-Cron als Config-Delta an
# Pattern: Research→Build-Feed
#
# Der Widevine-Research-Cron (9827948be189) federt neue Kernel-Patches,
# CDM-Alternativen oder Config-Flags ein. Dieses Script prüft, ob
# neue Erkenntnisse vorliegen und wandelt sie in Config-Deltas um.

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESEARCH_DIR="$SCRIPT_DIR/../research-patches"
CONFIG_DIR="$SCRIPT_DIR/config"

echo "=== Research → Build Feed ==="
echo ""

if [ ! -d "$RESEARCH_DIR" ]; then
    echo "No research patches directory. Create $RESEARCH_DIR and add .fragment files."
    echo "Format: research-patches/YYYY-MM-DD-description.fragment"
    echo "Content: One CONFIG_*=y/m per line"
    exit 0
fi

PATCHES=$(find "$RESEARCH_DIR" -name "*.fragment" -type f | sort)
if [ -z "$PATCHES" ]; then
    echo "No research patches found."
    exit 0
fi

echo "Found research patches:"
for p in $PATCHES; do
    echo "  $(basename "$p"):"
    sed 's/^/    /' "$p"
done

echo ""
echo "=== Applying research patches to config ==="

# Backup or create current delta
DELTA_FILE="$CONFIG_DIR/delta-reserved-heap.fragment"
if [ -f "$DELTA_FILE" ]; then
    cp "$DELTA_FILE" "${DELTA_FILE}.bak"
fi

# Merge all research patches into the delta
for p in $PATCHES; do
    echo "  + $(basename "$p")"
    cat "$p" >> "$DELTA_FILE"
done

# Dedup
sort -u "$CONFIG_DIR/delta-reserved-heap.fragment" -o "$CONFIG_DIR/delta-reserved-heap.fragment"

echo ""
echo "=== Updated config delta ==="
cat "$CONFIG_DIR/delta-reserved-heap.fragment"
echo ""
echo "Next: ./build.sh (to rebuild with new config)"
