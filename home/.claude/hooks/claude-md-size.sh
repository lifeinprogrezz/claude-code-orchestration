#!/usr/bin/env bash
# PostToolUse hook: after any Edit/Write, warn if a CLAUDE.md or MEMORY.md
# crossed its context budget. These files are auto-loaded into every session;
# over budget, Claude Code truncates them and rules/pointers silently drop.
# Surfaces a note back to the model so the next edit can condense instead of grow.
set -euo pipefail

input=$(cat)
fp=$(printf '%s' "$input" | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path","") or "")
except Exception:
    print("")' 2>/dev/null || true)

[ -z "${fp:-}" ] && exit 0
[ -f "$fp" ] || exit 0

warn=""
case "$(basename "$fp")" in
  CLAUDE.md)
    # Bytes (wc -c), not chars — bytes >= chars in UTF-8, so the byte budget is the
    # safer truncation proxy and is consistent with the MEMORY.md branch below and the
    # `wc -c` the CLAUDE.md size-budget header tells editors to use (audit A1, 2026-06-26).
    n=$(wc -c < "$fp" 2>/dev/null || echo 0)
    if [ "$n" -gt 40000 ]; then
      warn="⚠️ ${fp} is ${n} bytes — OVER the 40,000 budget. Condense an old section (keep the invariant + a pointer to the enforcing code/test/spec; move rationale/examples out) before adding more. Test-pinned rules lose nothing when condensed."
    fi
    ;;
  MEMORY.md)
    n=$(wc -c < "$fp" 2>/dev/null || echo 0)
    if [ "$n" -gt 24985 ]; then
      warn="⚠️ ${fp} is ${n} bytes — OVER the ~24.4 KB budget. Shorten the longest index descriptions (detail belongs in the topic file), or de-index dead Historical/SUPERSEDED/Closed entries, before adding more."
    fi
    ;;
  *) exit 0 ;;
esac

[ -z "$warn" ] && exit 0
printf '%s\n' "$warn" >&2
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":%s}}\n' \
  "$(printf '%s' "$warn" | python3 -c 'import sys,json;print(json.dumps(sys.stdin.read()))')"
exit 0
