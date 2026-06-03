#!/usr/bin/env bash
# install.sh — wire this repo's canonical Claude config into ~/.claude (idempotent).
# Symlinks user-owned files (CLAUDE.md, hooks/); MERGES managed keys into the
# app-owned settings.json (symlinking it is fragile — the app rewrites it).
# Backs up anything it replaces. Re-runnable. CLAUDE_HOME overrides ~/.claude (tests).
#
# NOTE: the jq merge ('.[0] * .[1]') deep-merges objects but REPLACES arrays. Your
# machine-specific permission allows belong in settings.local.json (never touched
# here), not settings.json — else a re-run would overwrite them.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
TS=$(date +%Y%m%d-%H%M%S); BK="$CLAUDE_DIR/backups/$TS"
mkdir -p "$CLAUDE_DIR/hooks"

link() { local rel="$1" target="$CLAUDE_DIR/$1" src="$REPO/home/.claude/$1"
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then echo "ok (already linked): $rel"; return; fi
  if [ -e "$target" ] || [ -L "$target" ]; then mkdir -p "$BK/$(dirname "$rel")"; mv "$target" "$BK/$rel"; echo "backed up: $rel"; fi
  ln -s "$src" "$target"; echo "linked: $rel -> $src"
}
link CLAUDE.md
link hooks/secrets-scan.sh

SET="$CLAUDE_DIR/settings.json"; FRAG="$REPO/home/.claude/settings.fragment.json"
if ! command -v jq >/dev/null 2>&1; then echo "WARN: jq missing — symlinks done, but settings NOT merged, so the secrets-scan hook is INACTIVE. Install jq (sudo apt install jq) and re-run." >&2; exit 0; fi
if [ -f "$SET" ]; then
  tmp=$(mktemp)
  if ! jq -s '.[0] * .[1]' "$SET" "$FRAG" > "$tmp"; then
    rm -f "$tmp"
    echo "ERROR: $SET is not valid JSON; left unchanged. Fix it and re-run." >&2
    exit 1
  fi
  if cmp -s "$tmp" "$SET"; then
    rm -f "$tmp"; echo "ok (settings already merged): settings.json"
  else
    mkdir -p "$BK"; cp "$SET" "$BK/settings.json"; mv "$tmp" "$SET"
    echo "merged settings fragment into settings.json (backup: $BK/settings.json)"
  fi
else
  cp "$FRAG" "$SET"; echo "created settings.json from fragment"
fi
echo "done."
