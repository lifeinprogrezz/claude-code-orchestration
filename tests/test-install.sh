#!/usr/bin/env bash
# install.sh contract: symlinks, settings merge (jq OR python3), CLAUDE.local.md preservation,
# hooks linked by directory, fail-closed on malformed settings. No jq needed to run this test.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
pass=0 fail=0; ok(){ echo "ok   - $1"; pass=$((pass+1)); }; no(){ echo "FAIL - $1"; fail=$((fail+1)); }
jget(){ python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    d=d[int(k)] if isinstance(d,list) else d[k]
print(json.dumps(d))' "$1" "$2" 2>/dev/null; }
# A PATH with every tool install.sh needs EXCEPT jq (symlink farm), so the python3 merge path runs.
nojq_dir=$(mktemp -d)
for t in bash sh python3 ln mv cp mkdir rm cat ls find grep sort uniq tr sed cmp mktemp date readlink dirname basename wc env true false test; do
  b=$(command -v "$t" 2>/dev/null) && ln -sf "$b" "$nojq_dir/$t"
done
nojq_path(){ echo "$nojq_dir"; }

# --- 1) standard install over an existing settings.json + plain CLAUDE.md, no CLAUDE.local.md
sb=$(mktemp -d); trap 'rm -rf "$sb" "${sb2:-}" "${sb3:-}" "$nojq_dir"' EXIT
export CLAUDE_HOME="$sb/.claude"; mkdir -p "$CLAUDE_HOME"
printf '{"permissions":{"defaultMode":"auto"},"enabledPlugins":{"x":true},"theme":"dark"}\n' > "$CLAUDE_HOME/settings.json"
printf '# old global\n' > "$CLAUDE_HOME/CLAUDE.md"
bash "$REPO/install.sh" >/dev/null 2>&1 || { echo "FAIL: install.sh errored"; exit 1; }

[ -L "$CLAUDE_HOME/CLAUDE.md" ] && [ "$(readlink "$CLAUDE_HOME/CLAUDE.md")" = "$REPO/home/.claude/CLAUDE.md" ] && ok "CLAUDE.md symlinked" || no "CLAUDE.md symlinked"
[ "$(cat "$CLAUDE_HOME/CLAUDE.local.md")" = "# old global" ] && ok "plain CLAUDE.md preserved as CLAUDE.local.md" || no "plain CLAUDE.md preserved as CLAUDE.local.md"
ls "$CLAUDE_HOME"/backups/*/CLAUDE.md >/dev/null 2>&1 && ok "backed up replaced CLAUDE.md" || no "backup made"
[ -L "$CLAUDE_HOME/hooks/secrets-scan.sh" ] && ok "hook symlinked" || no "hook symlinked"
nh=$(ls "$REPO"/home/.claude/hooks/*.sh | wc -l); nl=$(find "$CLAUDE_HOME/hooks" -maxdepth 1 -type l | wc -l)
[ "$nh" = "$nl" ] && ok "every repo hook linked ($nh)" || no "every repo hook linked (repo=$nh linked=$nl)"
[ -z "$(find "$CLAUDE_HOME" -xtype l)" ] && ok "no dangling symlinks" || no "no dangling symlinks"
[ "$(jget "$CLAUDE_HOME/settings.json" hooks.PreToolUse.0.matcher)" = '"Bash"' ] && ok "settings has hooks" || no "settings has hooks"
[ "$(jget "$CLAUDE_HOME/settings.json" enabledPlugins.x)" = "true" ] && [ "$(jget "$CLAUDE_HOME/settings.json" theme)" = '"dark"' ] && ok "settings preserved top-level keys + extra plugin" || no "settings preserved top-level keys"
[ "$(jget "$CLAUDE_HOME/settings.json" permissions.defaultMode)" = '"auto"' ] && jget "$CLAUDE_HOME/settings.json" permissions.allow | grep -q 'git commit' && ok "nested permissions.defaultMode survived + fragment allow merged" || no "nested permissions survival"
bash "$REPO/install.sh" >/dev/null 2>&1 && ok "idempotent re-run" || no "idempotent re-run"
[ -L "$CLAUDE_HOME/CLAUDE.md" ] && [ "$(cat "$CLAUDE_HOME/CLAUDE.local.md")" = "# old global" ] && ok "re-run leaves CLAUDE.local.md untouched" || no "re-run leaves CLAUDE.local.md untouched"

# --- 2) existing CLAUDE.local.md is never clobbered; old CLAUDE.md only backed up
sb2=$(mktemp -d); export CLAUDE_HOME="$sb2/.claude"; mkdir -p "$CLAUDE_HOME"
printf '# mine\n' > "$CLAUDE_HOME/CLAUDE.local.md"; printf '# old\n' > "$CLAUDE_HOME/CLAUDE.md"
bash "$REPO/install.sh" >/dev/null 2>&1
[ "$(cat "$CLAUDE_HOME/CLAUDE.local.md")" = "# mine" ] && ok "existing CLAUDE.local.md untouched" || no "existing CLAUDE.local.md untouched"
grep -q '# old' "$CLAUDE_HOME"/backups/*/CLAUDE.md 2>/dev/null && ok "old CLAUDE.md backed up when local exists" || no "old CLAUDE.md backed up when local exists"
[ -f "$CLAUDE_HOME/settings.json" ] && ok "settings.json created from fragment when absent" || no "settings.json created when absent"

# --- 3) no jq on PATH -> python3 merge, same result shape
sb3=$(mktemp -d); export CLAUDE_HOME="$sb3/.claude"; mkdir -p "$CLAUDE_HOME"
printf '{"permissions":{"defaultMode":"auto"},"enabledPlugins":{"remember@x":true},"theme":"dark"}\n' > "$CLAUDE_HOME/settings.json"
PATH="$(nojq_path)" bash "$REPO/install.sh" >/dev/null 2>&1 || no "install without jq exits 0"
[ "$(jget "$CLAUDE_HOME/settings.json" hooks.PreToolUse.0.matcher)" = '"Bash"' ] && ok "no-jq: hooks merged via python3" || no "no-jq: hooks merged via python3"
[ "$(jget "$CLAUDE_HOME/settings.json" enabledPlugins.remember@x)" = "true" ] && [ "$(jget "$CLAUDE_HOME/settings.json" permissions.defaultMode)" = '"auto"' ] && ok "no-jq: extra plugin + nested keys survive" || no "no-jq: extra plugin + nested keys survive"
if command -v jq >/dev/null 2>&1; then
  a=$(jq -S . "$CLAUDE_HOME/settings.json"); b=$(sed 's/"x": true/"remember@x": true/' "$sb/.claude/settings.json" | jq -S .)
  [ "$a" = "$b" ] && ok "no-jq merge == jq merge" || no "no-jq merge == jq merge"
fi
# malformed settings.json -> FAIL CLOSED on the python3 path too
printf '{bad json' > "$CLAUDE_HOME/settings.json"
err=$(PATH="$(nojq_path)" bash "$REPO/install.sh" 2>&1); rc=$?
{ [ "$rc" -ne 0 ] && echo "$err" | grep -q 'not valid JSON'; } && ok "no-jq: malformed settings -> honest non-zero error" || no "no-jq: malformed settings handling (rc=$rc)"
[ "$(cat "$CLAUDE_HOME/settings.json")" = '{bad json' ] && ok "no-jq: malformed settings left unchanged" || no "no-jq: malformed settings left unchanged"

# --- 4) malformed settings.json with jq -> FAIL CLOSED (original case)
printf '{bad json' > "$CLAUDE_HOME/settings.json"
err=$(bash "$REPO/install.sh" 2>&1); rc=$?
{ [ "$rc" -ne 0 ] && echo "$err" | grep -q 'not valid JSON'; } && ok "malformed settings.json -> honest non-zero error" || no "malformed settings handling (rc=$rc)"

echo "----"; echo "PASS=$pass FAIL=$fail"; [ "$fail" -eq 0 ] || exit 1
