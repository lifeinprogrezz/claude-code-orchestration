#!/usr/bin/env bash
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
pass=0 fail=0; ok(){ echo "ok   - $1"; pass=$((pass+1)); }; no(){ echo "FAIL - $1"; fail=$((fail+1)); }
sb=$(mktemp -d); trap 'rm -rf "$sb"' EXIT
export CLAUDE_HOME="$sb/.claude"; mkdir -p "$CLAUDE_HOME"
printf '{"permissions":{"defaultMode":"auto"},"enabledPlugins":{"x":true},"theme":"dark"}\n' > "$CLAUDE_HOME/settings.json"
printf '# old global\n' > "$CLAUDE_HOME/CLAUDE.md"

bash "$REPO/install.sh" >/dev/null 2>&1 || { echo "FAIL: install.sh errored"; exit 1; }

[ -L "$CLAUDE_HOME/CLAUDE.md" ] && [ "$(readlink "$CLAUDE_HOME/CLAUDE.md")" = "$REPO/home/.claude/CLAUDE.md" ] && ok "CLAUDE.md symlinked" || no "CLAUDE.md symlinked"
[ -L "$CLAUDE_HOME/hooks/secrets-scan.sh" ] && ok "hook symlinked" || no "hook symlinked"
jq -e '.hooks.PreToolUse' "$CLAUDE_HOME/settings.json" >/dev/null 2>&1 && ok "settings has hooks" || no "settings has hooks"
jq -e '.enabledPlugins.x==true and .theme=="dark"' "$CLAUDE_HOME/settings.json" >/dev/null 2>&1 && ok "settings preserved top-level keys" || no "settings preserved top-level keys"
jq -e '.permissions.defaultMode=="auto" and (.permissions.allow|index("Bash(git commit*)"))' "$CLAUDE_HOME/settings.json" >/dev/null 2>&1 && ok "nested permissions.defaultMode survived + fragment allow merged" || no "nested permissions survival"
ls "$CLAUDE_HOME"/backups/*/CLAUDE.md >/dev/null 2>&1 && ok "backed up replaced CLAUDE.md" || no "backup made"
bash "$REPO/install.sh" >/dev/null 2>&1 && ok "idempotent re-run" || no "idempotent re-run"
[ -L "$CLAUDE_HOME/CLAUDE.md" ] && ok "still linked after re-run" || no "still linked after re-run"

# malformed settings.json -> must FAIL CLOSED (exit !=0), leave file unchanged, clear error
sb2=$(mktemp -d); export CLAUDE_HOME="$sb2/.claude"; mkdir -p "$CLAUDE_HOME"
printf '{bad json' > "$CLAUDE_HOME/settings.json"
err=$(bash "$REPO/install.sh" 2>&1); rc=$?
{ [ "$rc" -ne 0 ] && echo "$err" | grep -q 'not valid JSON'; } && ok "malformed settings.json -> honest non-zero error" || no "malformed settings handling (rc=$rc)"
[ "$(cat "$CLAUDE_HOME/settings.json")" = '{bad json' ] && ok "malformed settings.json left unchanged" || no "malformed settings left unchanged"
rm -rf "$sb2"

echo "----"; echo "PASS=$pass FAIL=$fail"; [ "$fail" -eq 0 ] || exit 1
