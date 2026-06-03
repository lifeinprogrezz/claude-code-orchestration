#!/usr/bin/env bash
# secrets-scan.sh — canonical Claude Code PreToolUse hook (repo = source of truth).
# Installed by install.sh (symlinked) to ~/.claude/hooks/secrets-scan.sh; also invoked by cc-autopilot.sh.
# Gated in settings.json to `git commit` and `git push`. Blocks if the change about to
# be recorded/pushed looks like credentials:
#   1) a real .env file (allows .example/.sample/.template/.dist)
#   2) credential-looking assignments (api_key/secret/token/password/... = 12+ chars)
#   3) known key prefixes (Stripe / GitHub / Slack / AWS / PEM private keys)
# A per-repo `.secrets-scan-allow` (path globs, one per line, # comments ok) excludes
# files that legitimately hold secret-looking text (tests, security docs, examples).
# FAILS CLOSED: on any internal git/parse error it BLOCKS (a blocked push is cheap; a
# leaked key is not). To fail-OPEN on an interactive-only machine, edit FAIL_OPEN below.
# Known limitation: `git -C <other-repo> push` inspects the CURRENT repo, not the -C
# target; cd into the repo for full coverage.
# Requires: git, python3. jq optional (nicer structured deny).
set -uo pipefail
FAIL_OPEN=0   # in-file toggle: change to 1 to fail-OPEN (allow) on interactive-only machines

fail_closed() {
  [ "${FAIL_OPEN:-0}" -eq 1 ] && exit 0
  echo "secrets-scan: internal error ($1); blocking (fail-closed). To allow, set FAIL_OPEN=1 in this hook." >&2
  exit 2
}

payload=$(cat 2>/dev/null) || true
cmd=$(printf '%s' "$payload" | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception:
    sys.exit(3)' 2>/dev/null) || fail_closed "stdin/json parse failed"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0   # not a repo: nothing to guard

# Per-repo allowlist -> git pathspec excludes (repo-root-relative). Trim surrounding ws only.
excludes=()
root=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$root" ] && [ -f "$root/.secrets-scan-allow" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] && excludes+=( ":(exclude,top)$line" )
  done < "$root/.secrets-scan-allow"
fi

# push? match `git [opts...] push` so `git -c k=v push` / `git --opt push` are caught too.
is_push=0
printf '%s' "$cmd" | grep -qE '(^|[^[:alnum:]])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+push' && is_push=1

if [ "$is_push" -eq 1 ]; then
  if base=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then :
  elif base=$(git rev-parse --verify --quiet origin/HEAD 2>/dev/null); then :
  else base=$(git hash-object -t tree /dev/null); fi
  raw=$(git diff "${base}..HEAD" --unified=0 -- . "${excludes[@]}" 2>/dev/null) || fail_closed "git diff (push range) failed"
  files=$(git diff --name-only "${base}..HEAD" -- . "${excludes[@]}" 2>/dev/null) || fail_closed "git name-only (push range) failed"
else
  raw=$(git diff --cached --unified=0 -- . "${excludes[@]}" 2>/dev/null) || fail_closed "git diff --cached failed"
  files=$(git diff --cached --name-only -- . "${excludes[@]}" 2>/dev/null) || fail_closed "git name-only --cached failed"
fi

added=$(printf '%s\n' "$raw" | grep -E '^\+' | grep -vE '^\+\+\+' || true)
scan=$(printf '%s\n' "$added" | tr -d "\"'")

env_file=$(printf '%s\n' "$files" | grep -E '(^|/)\.env($|\.)' | grep -Eiv '\.(example|sample|template|dist)$' || true)

assign='(api[_-]?key|secret|token|passwd|password|access[_-]?key|private[_-]?key|client[_-]?secret)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9/+_-]{12,}'
prefix='(sk_(live|test)_|rk_live_|gh[posru]_|github_pat_|xox[baprs]-|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'
# Skip placeholders only in VALUE position (after :=) or <template> tokens — NOT bare
# substrings like "example" that legitimately appear in key names / URLs.
placeholder='(<[^>]+>|[:=][[:space:]]*"?(your[_-]|xxx+|changeme\b|placeholder\b|dummy\b|example\b|example[_-]))'

hits=$(printf '%s\n' "$scan" | grep -EiI -e "$assign" -e "$prefix" | grep -Eiv "$placeholder" || true)
n=$(printf '%s\n' "$hits" | grep -c . || true)

if [ -n "$env_file" ] || [ "${n:-0}" -gt 0 ]; then
  what=$([ "$is_push" -eq 1 ] && echo push || echo commit)
  reason="BLOCKED by secrets-scan: this $what looks like it contains credentials."
  [ -n "$env_file" ] && reason+=$'\n  - env file(s): '"$env_file"
  [ "${n:-0}" -gt 0 ] && reason+=$'\n  - '"$n"' line(s) matched a key/secret pattern'
  reason+=$'\nMove it to an env var / secrets manager and retry. Legit fixture/example? Add its path to .secrets-scan-allow.'
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    exit 0
  fi
  echo "$reason" >&2; exit 2
fi
exit 0
