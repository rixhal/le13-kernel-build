#!/bin/bash
# sync-to-remotes.sh — Läuft nach jedem Build/Auto-Update
# Committed + pushed zu beiden Remotes

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Syncing to remotes ==="

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Changes detected — committing..."
    git add -A
    git commit -m "auto: $(date +%Y-%m-%d) — build $(cat build-output/BUILD_INFO.txt 2>/dev/null | grep 'Kernel commit:' | head -1 || echo 'update')"
else
    echo "No changes to commit"
fi

echo "→ GitHub"
git push origin main 2>&1 | tail -1

echo "→ Forgejo"
git push forgejo main 2>&1 | tail -1

echo ""
echo "=== Remotes synced ==="
