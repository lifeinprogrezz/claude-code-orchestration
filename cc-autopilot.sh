#!/usr/bin/env bash
# cc-autopilot — run a Claude Code task headless, then push only if a secret scan passes.
#
# Usage:   cc-autopilot /path/to/repo "the task prompt"
# Env:
#   USE_ROUTER=1        route through claude-code-router (API/credit plane, model failover)
#   AUTOPILOT_BRANCH=x  do the work on a dedicated branch instead of the current one
#
set -euo pipefail

REPO="${1:?repo path required}"
TASK="${2:?task prompt required}"
BRANCH="${AUTOPILOT_BRANCH:-}"
LOG_DIR="${HOME}/.cc-autopilot/logs"
mkdir -p "$LOG_DIR"
LOG="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)-$(basename "$REPO").log"
exec > >(tee -a "$LOG") 2>&1

echo "[$(date -Is)] autopilot start: repo=$REPO"
cd "$REPO"
git rev-parse --is-inside-work-tree >/dev/null

# plain `claude` = subscription/API key cached on this box; `ccr code` = routed/failover
if [[ "${USE_ROUTER:-0}" == "1" ]]; then RUN=(ccr code); else RUN=(claude); fi

git pull --ff-only || echo "warn: pull skipped (diverged or offline)"
[[ -n "$BRANCH" ]] && git switch -C "$BRANCH"

echo "[$(date -Is)] running claude (headless)…"
# Default to scoped tools. For true unattended autopilot on an ISOLATED box,
# uncomment the bypass line and remove --allowedTools.
"${RUN[@]}" -p "$TASK" \
  --allowedTools "Read,Edit,Write,Bash"
  # --dangerously-skip-permissions

# ---------- SECRET SCAN via the canonical hook (single source of truth) ----------
# Reuses ~/.claude/hooks/secrets-scan.sh (installed by install.sh) so the autopilot
# and interactive Claude Code enforce the EXACT same rules + per-repo .secrets-scan-allow.
echo "[$(date -Is)] secret scan (canonical hook)…"
git add -A
HOOK="${SECRETS_SCAN_HOOK:-$HOME/.claude/hooks/secrets-scan.sh}"
if [[ ! -x "$HOOK" ]]; then
  echo "[$(date -Is)] BLOCK: secrets-scan hook missing at $HOOK — run install.sh first. Nothing pushed."
  git reset >/dev/null; exit 2
fi
# The hook blocks via a "deny" JSON (when jq present, exit 0) OR a non-zero exit.
set +e
scan_out="$(printf '{"tool_input":{"command":"git commit"}}' | "$HOOK" 2>&1)"; scan_rc=$?
set -e
if [[ "$scan_rc" -ne 0 ]] || printf '%s' "$scan_out" | grep -q '"permissionDecision":"deny"'; then
  echo "[$(date -Is)] SECRET SCAN FAILED — nothing pushed:"
  printf '%s\n' "$scan_out"
  echo "Review: $LOG"
  git reset >/dev/null; exit 2
fi

if git diff --cached --quiet; then
  echo "[$(date -Is)] no changes to commit"; exit 0
fi

git commit -m "autopilot: ${TASK:0:60}"
if [[ -n "$BRANCH" ]]; then git push -u origin "$BRANCH"; else git push; fi
echo "[$(date -Is)] autopilot done: pushed"
