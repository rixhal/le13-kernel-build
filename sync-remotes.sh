#!/usr/bin/env bash
# Sync to both remotes (GitHub + Forgejo)
set -euo pipefail

BRANCH="${1:-main}"
MSG="${2:-chore: isa-build repo update}"

echo "=== Sync to both remotes (branch: $BRANCH) ==="

git add -A
git commit -m "$MSG" || echo "Nothing to commit"

git push origin "$BRANCH" 2>/dev/null && echo "origin (GitHub): OK" || echo "origin: skippped"
git push forgejo "$BRANCH" 2>/dev/null && echo "forgejo: OK" || echo "forgejo: skipped"

echo "=== Sync done ==="
