#!/usr/bin/env bash
# redact-secrets.py contract: every secret kind -> [REDACTED:<kind>], placeholders and clean
# lines byte-identical, markdown structure irrelevant (fence/table), --in-place rewrites *.md,
# and the redacted output passes the secrets-scan hook when staged.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"; R="$REPO/tools/redact-secrets.py"; HOOK="$REPO/home/.claude/hooks/secrets-scan.sh"
pass=0 fail=0; ok(){ echo "ok   - $1"; pass=$((pass+1)); }; no(){ echo "FAIL - $1"; fail=$((fail+1)); }
[ -f "$R" ] || { echo "FAIL: $R missing"; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/page.md" <<'FIX'
# Config page
API_KEY=sk_live_0123456789abcdef
client_secret = abcdefghijklmnop123456
token: ghp_0123456789abcdefghij0123456789abcd
slack = xoxb-123456789012-abcdefghijkl
aws_key: AKIAABCDEFGHIJKLMNOP
Authorization: Bearer abcdefghijklmnopqrstuvwxyz0123456789
jwt eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c
```yaml
password: hunter2hunter2hunter2
```
| token | ghp_0123456789abcdefghij0123456789abcd |
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA
-----END RSA PRIVATE KEY-----
API_KEY=your_key_here
The deploy runs at 09:00 and posts to #ops.
FIX
out=$(python3 "$R" < "$tmp/page.md")
has(){ printf '%s\n' "$out" | grep -qF -- "$1"; }
has 'API_KEY=[REDACTED:stripe]' && ok "stripe prefix wins inside an assignment" || no "stripe prefix"
has 'client_secret = [REDACTED:assign]' && ok "assign kind (key kept, value redacted)" || no "assign kind"
has 'token: [REDACTED:github]' && ok "github prefix" || no "github prefix"
has '[REDACTED:slack]' && ok "slack prefix" || no "slack prefix"
has '[REDACTED:aws]' && ok "aws prefix" || no "aws prefix"
has 'Bearer [REDACTED:bearer]' && ok "bearer token" || no "bearer token"
has 'jwt [REDACTED:jwt]' && ok "jwt" || no "jwt"
has 'password: [REDACTED:assign]' && ok "inside a code fence" || no "inside a code fence"
has '| token | [REDACTED:github] |' && ok "inside a table row" || no "inside a table row"
has '[REDACTED:pem]' && ! has 'MIIEowIBAAKCAQEA' && ! has 'BEGIN RSA' && ok "pem block replaced whole" || no "pem block replaced whole"
has 'API_KEY=your_key_here' && ok "placeholder untouched" || no "placeholder untouched"
has 'The deploy runs at 09:00 and posts to #ops.' && ok "clean line untouched" || no "clean line untouched"
has '# Config page' && ok "markdown kept" || no "markdown kept"
printf '%s\n' "$out" | grep -qE 'sk_live_|ghp_0|xoxb-|AKIAA|hunter2' && no "no secret survives" || ok "no secret survives"
# idempotent
[ "$(printf '%s\n' "$out" | python3 "$R")" = "$out" ] && ok "idempotent" || no "idempotent"
# --in-place over a dir
mkdir -p "$tmp/mirror/sub"; cp "$tmp/page.md" "$tmp/mirror/sub/p.md"; printf 'clean\n' > "$tmp/mirror/c.md"; printf 'x=sk_live_0123456789abcdef\n' > "$tmp/mirror/not-md.txt"
python3 "$R" --in-place "$tmp/mirror" >/dev/null
grep -q 'REDACTED' "$tmp/mirror/sub/p.md" && [ "$(cat "$tmp/mirror/c.md")" = "clean" ] && grep -q 'sk_live' "$tmp/mirror/not-md.txt" && ok "--in-place rewrites *.md only" || no "--in-place rewrites *.md only"
# redacted output passes the hook when staged
( cd "$tmp" && git init -q && git config user.email t@t && git config user.name t && printf '%s\n' "$out" > page.md && git add page.md
  r=$(printf '{"tool_input":{"command":"git commit -m x"}}' | bash "$HOOK" 2>&1; printf 'EXIT:%s' "$?")
  echo "$r" | grep -q 'EXIT:0' && ! echo "$r" | grep -q '"deny"' && echo HOOKOK ) | grep -q HOOKOK && ok "redacted output passes secrets-scan" || no "redacted output passes secrets-scan"
( cd "$tmp" && cp "$tmp/mirror/not-md.txt" raw.txt && git add raw.txt
  r=$(printf '{"tool_input":{"command":"git commit -m x"}}' | bash "$HOOK" 2>&1; printf 'EXIT:%s' "$?")
  echo "$r" | grep -qE '"deny"|EXIT:2' && echo HOOKBLOCK ) | grep -q HOOKBLOCK && ok "control: unredacted input is blocked" || no "control: unredacted input is blocked"
echo "----"; echo "PASS=$pass FAIL=$fail"; [ "$fail" -eq 0 ] || exit 1
