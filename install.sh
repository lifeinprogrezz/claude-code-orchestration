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
# A pre-existing PLAIN CLAUDE.md (a machine that had its own global profile before this
# repo) is preserved as CLAUDE.local.md — the work profile imports it at the end, so the
# machine's own rules keep loading. Never clobbers an existing CLAUDE.local.md (backup only).
if [ -f "$CLAUDE_DIR/CLAUDE.md" ] && [ ! -L "$CLAUDE_DIR/CLAUDE.md" ]; then
  mkdir -p "$BK"; cp "$CLAUDE_DIR/CLAUDE.md" "$BK/CLAUDE.md"
  if [ ! -e "$CLAUDE_DIR/CLAUDE.local.md" ]; then
    mv "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.local.md"
    echo "preserved: CLAUDE.md -> CLAUDE.local.md (the kit CLAUDE.md imports it; backup: $BK/CLAUDE.md)"
  fi
fi
[ -e "$CLAUDE_DIR/CLAUDE.local.md" ] || : > "$CLAUDE_DIR/CLAUDE.local.md"
link CLAUDE.md
# Deploy EVERY hook shipped in home/.claude/hooks/ (audit F1, 2026-06-26: a fresh machine
# once shipped only secrets-scan.sh, leaving the other rails dead). Linking by directory
# means the same install.sh serves the laptop (3 hooks) and the work kit (2 hooks); the
# post-install assertion below still proves every hook the fragment WIRES is present.
for h in "$REPO"/home/.claude/hooks/*.sh; do [ -f "$h" ] && link "hooks/$(basename "$h")"; done

# ccr-which identity verifier → ~/.local/bin (the global CLAUDE.md leads every turn
# with its output; without it on PATH the model-identity rail is dead). Idempotent.
CCR_WHICH_SRC="$REPO/tools/ccr-which"
CCR_WHICH_DST="$HOME/.local/bin/ccr-which"
if [ -f "$CCR_WHICH_SRC" ]; then
  mkdir -p "$HOME/.local/bin"
  if [ -L "$CCR_WHICH_DST" ] && [ "$(readlink "$CCR_WHICH_DST")" = "$CCR_WHICH_SRC" ]; then
    echo "ok (already linked): ~/.local/bin/ccr-which"
  else
    [ -e "$CCR_WHICH_DST" ] || [ -L "$CCR_WHICH_DST" ] && { mkdir -p "$BK"; mv "$CCR_WHICH_DST" "$BK/ccr-which" 2>/dev/null || true; }
    ln -sf "$CCR_WHICH_SRC" "$CCR_WHICH_DST"; echo "linked: ~/.local/bin/ccr-which -> $CCR_WHICH_SRC"
  fi
fi

# Global skills (audit G3) — symlink each managed skill dir from the repo into
# ~/.claude/skills/ so every machine has the same global capability skills (the
# project-agnostic ones; project skills stay in each project's .claude/skills/).
# Backs up a pre-existing non-symlink dir. Machine-local skills not in the repo are left alone.
if [ -d "$REPO/home/.claude/skills" ]; then
  mkdir -p "$CLAUDE_DIR/skills"
  for sdir in "$REPO"/home/.claude/skills/*/; do
    [ -d "$sdir" ] || continue
    name="$(basename "$sdir")"; dst="$CLAUDE_DIR/skills/$name"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "${sdir%/}" ]; then echo "ok (already linked): skills/$name"; continue; fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then mkdir -p "$BK/skills"; mv "$dst" "$BK/skills/$name"; echo "backed up: skills/$name"; fi
    ln -s "${sdir%/}" "$dst"; echo "linked: skills/$name -> ${sdir%/}"
  done
fi

SET="$CLAUDE_DIR/settings.json"; FRAG="$REPO/home/.claude/settings.fragment.json"
# Deep-merge FRAG into SET -> stdout. jq if present, else python3 with the same semantics
# (objects merge recursively, arrays and scalars are replaced). Non-zero on invalid JSON.
merge_settings() {
  if command -v jq >/dev/null 2>&1; then jq -s '.[0] * .[1]' "$1" "$2"
  else python3 - "$1" "$2" <<'PYMERGE'
import json, sys
def merge(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        r = dict(a)
        for k, v in b.items(): r[k] = merge(a.get(k), v)
        return r
    return b
try:
    a = json.load(open(sys.argv[1], encoding="utf-8")); b = json.load(open(sys.argv[2], encoding="utf-8"))
except Exception as e:
    sys.exit(4)
print(json.dumps(merge(a, b), indent=2))
PYMERGE
  fi
}
if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then echo "WARN: neither jq nor python3 found — symlinks done, but settings NOT merged, so the hooks are INACTIVE. Install one (sudo apt install jq) and re-run." >&2; exit 0; fi
if [ -f "$SET" ]; then
  tmp=$(mktemp)
  if ! merge_settings "$SET" "$FRAG" > "$tmp"; then
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

# Post-install assertion (audit F1): every hook the fragment WIRES must resolve to a
# real file under ~/.claude/hooks, else a wired-but-undeployed hook fails silently
# every session. Fail loudly so a broken provision is caught at install time.
missing=0
for h in $(grep -oE '[a-zA-Z0-9_-]+\.sh' "$FRAG" | sort -u); do
  if [ ! -e "$CLAUDE_DIR/hooks/$h" ]; then echo "ASSERT FAIL: settings wires hooks/$h but it is not deployed" >&2; missing=1; fi
done
# G3: assert the declarative toolchain manifest is satisfied — every managed global skill
# is deployed, and every enabled plugin in the fragment is actually installed (warn-only:
# plugins install from the marketplace, not by this script — see skills-manifest.json).
MAN="$REPO/skills-manifest.json"
jlist() { python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d=d.get(k,{}) if isinstance(d,dict) else {}
print("\n".join(d) if isinstance(d,list) else "")' "$1" "$2" 2>/dev/null; }
if command -v python3 >/dev/null 2>&1 && [ -f "$MAN" ]; then
  for s in $(jlist "$MAN" globalSkills.managed); do
    if [ ! -e "$CLAUDE_DIR/skills/$s" ]; then echo "ASSERT FAIL: manifest lists global skill '$s' but it is not deployed" >&2; missing=1; fi
  done
  INST="$HOME/.claude/plugins/installed_plugins.json"
  for p in $(jlist "$MAN" plugins.enabled); do
    if [ -f "$INST" ] && ! grep -q "\"$p" "$INST" 2>/dev/null; then
      echo "note: plugin '$p' is enabled in the fragment but not yet installed — run: claude plugin install ${p}@claude-plugins-official (see skills-manifest.json)" >&2
    fi
  done
fi
if [ "$missing" = 1 ]; then echo "ERROR: one or more wired hooks/skills are missing — see above." >&2; exit 1; fi
echo "post-install: all wired hooks + managed skills present ✓"
echo "done."
