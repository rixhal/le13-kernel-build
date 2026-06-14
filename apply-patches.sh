#!/usr/bin/env bash
# Apply research patches from research-patches/ to ISA source
set -euo pipefail

ISA_DIR="${1:-inputstream.adaptive}"

for patch in research-patches/*.patch; do
    [ -f "$patch" ] || continue
    echo "Applying: $(basename "$patch")"
    cd "$ISA_DIR"
    if patch -p1 --dry-run < "../$patch" 2>/dev/null; then
        patch -p1 < "../$patch"
        echo "  → applied"
    else
        echo "  → bereits angewendet oder nicht anwendbar, skip"
    fi
    cd ..
done

echo "Done."
