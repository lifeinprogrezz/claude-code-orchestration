#!/usr/bin/env bash
# Verifies the canonical hook: BLOCKS secrets (commit + push paths), ALLOWS clean
# diffs / placeholders / allowlisted paths, and FAILS CLOSED on internal git error.
set -uo pipefail
HOOK="${1:?usage: test-secrets-scan.sh /path/to/secrets-scan.sh}"
HOOK="$(cd "$(dirname "$HOOK")" 2>/dev/null && pwd)/$(basename "$HOOK")"   # resolve to absolute
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }
pass=0 fail=0
run() { printf '{"tool_input":{"command":"%s"}}' "$1" | bash "$HOOK" 2>&1; printf 'EXIT:%s' "$?"; }
expect() { local ok=1
  if [ "$2" = block ]; then echo "$3" | grep -qE '"deny"|EXIT:2' || ok=0
  else { echo "$3" | grep -q 'EXIT:0' && ! echo "$3" | grep -q '"deny"'; } || ok=0; fi
  if [ "$ok" = 1 ]; then echo "ok   - $1"; pass=$((pass+1)); else echo "FAIL - $1 (wanted $2) :: $3"; fail=$((fail+1)); fi
}
clean() { git rm -r --cached -q . >/dev/null 2>&1 || true; git clean -fdq >/dev/null 2>&1 || true; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cd "$tmp" || { echo "FAIL: cannot cd $tmp"; exit 1; }
git init -q; git config user.email t@t; git config user.name t

printf 'API_KEY=sk_live_0123456789abcdef\n' > .env; git add .env
expect "A blocks staged .env" block "$(run 'git commit -m x')"; clean

printf 'API_KEY=your_key_here\n' > .env.example; git add .env.example
expect "B allows .env.example" allow "$(run 'git commit -m x')"; clean

printf 'const t = "ghp_0123456789abcdefghij0123456789abcd"\n' > app.js; git add app.js
expect "C blocks inline gh token" block "$(run 'git commit -m x')"; clean

printf 'export const sum=(a,b)=>a+b\n' > util.js; git add util.js
expect "D allows clean diff" allow "$(run 'git commit -m x')"; clean

printf 'docs/*\n' > .secrets-scan-allow; mkdir -p docs
printf 'token: ghp_0123456789abcdefghij0123456789abcd\n' > docs/guide.md
git add .secrets-scan-allow docs/guide.md
expect "E allows secret under allowlisted path" allow "$(run 'git commit -m x')"; clean

printf 'export EXAMPLE_API_KEY=sk_live_realsecretvalue123\n' > h.js; git add h.js
expect "H blocks secret despite example in key name" block "$(run 'git commit -m x')"; clean

printf 'API_KEY=your_key_here\n' > i.js; git add i.js
expect "I allows your_ placeholder value" allow "$(run 'git commit -m x')"; clean

# G) git diff errors mid-scan -> FAIL CLOSED (block)
stub=$(mktemp -d); realgit=$(command -v git)
cat > "$stub/git" <<EOG
#!/usr/bin/env bash
[ "\$1" = diff ] && exit 128
exec "$realgit" "\$@"
EOG
chmod +x "$stub/git"
printf 'API_KEY=sk_live_failclosed0123456789\n' > g.js; git add g.js
expect "G fail-closed on git diff error" block "$(PATH="$stub:$PATH" run 'git commit -m x')"; clean
rm -rf "$stub"

# F) push-path: secret in commits ahead of upstream -> BLOCK (own isolated repo)
fpush=$(mktemp -d); fbare=$(mktemp -d); ( cd "$fbare" && git init -q --bare )
( cd "$fpush"; git init -q; git config user.email t@t; git config user.name t
  git remote add origin "$fbare"; printf 'ok\n' > a.txt; git add a.txt; git commit -qm init; git push -qu origin HEAD
  printf 'KEY=sk_live_pushtest0123456789\n' > leak.js; git add leak.js; git commit -qm leak )
fout=$( cd "$fpush" && printf '{"tool_input":{"command":"git push"}}' | bash "$HOOK" 2>&1; printf 'EXIT:%s' "$?" )
expect "F blocks secret on push path" block "$fout"
fout2=$( cd "$fpush" && printf '{"tool_input":{"command":"git -c foo=bar push"}}' | bash "$HOOK" 2>&1; printf 'EXIT:%s' "$?" )
expect "F2 blocks secret on git -c push (regression for opt-prefixed push)" block "$fout2"
rm -rf "$fpush" "$fbare"

echo "----"; echo "PASS=$pass FAIL=$fail"; [ "$fail" -eq 0 ] || exit 1
