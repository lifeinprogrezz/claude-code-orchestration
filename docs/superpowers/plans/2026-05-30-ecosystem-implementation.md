# Two-Plane Claude Ecosystem — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Stand up Roberto's remote-control / 24-7 / agentic Claude Code ecosystem (two planes), folding in the worthy findings from the 8 `AgenticInstructions*` research folders. **Option B (full dotfiles):** this repo is the *canonical, version-controlled home* of the managed `~/.claude/` config; an `install.sh` wires it into any machine (laptop + VPS) identically.

**Architecture:** Phase 0 builds the dotfiles foundation — one canonical secrets-scan hook, the global behavioral layer, and an idempotent `install.sh` that **symlinks** the user-owned files (`CLAUDE.md`, `hooks/`) and **merges** the managed settings (hooks + git/gh permissions) into the app-owned `settings.json`. Phases 1–5 build outward: Plane 1 (web), Plane 2 (VPS, which just clones this repo + runs `install.sh`), the 24-7 agentic usage layer, an RTK experiment, and a capstone skill.

**Tech Stack:** Claude Code (hooks, settings.json, CLAUDE.md, /goal, agent view), bash + python3 + git + jq (hook + installer), claude-code-router + OpenRouter (Plane 2 capacity), Hetzner VPS + tmux/mosh + Termius (Plane 2 ops), React/Vercel (deploy layer, unchanged).

---

## Decisions locked

| # | Decision | Choice |
|---|----------|--------|
| Install model | A (copy) vs **B (dotfiles/symlink)** | **B** — repo is canonical; `install.sh` symlinks `CLAUDE.md`+`hooks/`, merges managed keys into `settings.json`. Reproducible on the VPS by clone+install. |
| settings.json | symlink vs merge | **Merge** (jq) — the app rewrites `settings.json`; symlinking it desyncs. `settings.local.json` stays local (already gitignored). |
| Scope | /audit + claude-mem | **Ecosystem-pure.** /audit = Phase 5 capstone; claude-mem deferred. |
| Experiments | RTK vs claude-mem | **RTK** earmarked Phase 4; claude-mem deferred (revisit if native memory visibly fails). |
| §11.1 VPS | provider/size | **Hetzner CX22** (~€4–5/mo), Nuremberg/Falkenstein; CX32 if running dev+builds+DB. Confirm before provisioning. |
| §11.2 LinkedIn | scan on VPS? | **Score-only** on laptop-produced data for v1. |
| §11.3 schedule | shape | On-demand first; then one `cron` for the morning pipeline. |
| §11.4 digests | mobile | Push markdown to repo → GitHub mobile app. |
| §11.5 slugs | model ids | Resolve live at Phase 2. Today: Opus 4.8 `claude-opus-4-8`, Sonnet 4.6 `claude-sonnet-4-6`, Haiku 4.5 `claude-haiku-4-5`. |

**Where each research folder landed:** F1 Karpathy → Task 3 (behavioral layer in canonical CLAUDE.md). F2 security kit → Tasks 1–2 (hook + install). F6 /goal+secrets-scan → Task 1 + Phase 3. F5 levelsio VPS → Phase 2. F7 agent view → Phase 3. F4 RTK → Phase 4. F3 /audit → Phase 5. F8 claude-mem → deferred.

---

## Phase 0 — Dotfiles foundation (DONE - live + pushed)

### Repo layout (target)

```
home/.claude/                       # canonical ~/.claude config (mirror); install.sh wires it in
├── CLAUDE.md                       #   = current ~/.claude/CLAUDE.md (verbatim) + behavioral layer  → SYMLINKED
├── hooks/secrets-scan.sh           #   canonical hook                                                → SYMLINKED
└── settings.fragment.json          #   managed keys (PreToolUse hooks + git/gh perms + .env deny)    → MERGED via jq
tests/test-secrets-scan.sh          # hook test harness
install.sh                          # idempotent: backup + symlink + jq-merge; CLAUDE_HOME override for sandbox tests
.secrets-scan-allow                 # per-repo allowlist for THIS repo
README.md, docs/                    # docs
bootstrap.sh, cc-autopilot.sh, ccr-config.json, ccr.service   # VPS kit — reorganised in Phase 2
```

### Task 1 — Canonical secrets-scan hook ✅ DONE
Commits `4b49700` → `1e683f0` (fail-closed + hardening) → `8246906` (docs + regression test). 10/10 tests pass; spec ✅, code-quality ✅. Currently at `kit/hooks/secrets-scan.sh` + `kit/tests/`; **Task 2 moves them** into the dotfiles layout.

### Task 2 — Restructure to dotfiles + author `install.sh` (test-first)

**Files:**
- Move: `kit/hooks/secrets-scan.sh` → `home/.claude/hooks/secrets-scan.sh`; `kit/tests/test-secrets-scan.sh` → `tests/test-secrets-scan.sh` (then remove empty `kit/`).
- Modify: `.secrets-scan-allow` (update paths).
- Create: `home/.claude/CLAUDE.md` (verbatim copy of current `~/.claude/CLAUDE.md`).
- Create: `home/.claude/settings.fragment.json`.
- Create: `install.sh`, `tests/test-install.sh`.

- [ ] **Step 1 — Move files (git mv) and fix the allowlist + test invocation path**

```bash
mkdir -p home/.claude/hooks tests
git mv kit/hooks/secrets-scan.sh home/.claude/hooks/secrets-scan.sh
git mv kit/tests/test-secrets-scan.sh tests/test-secrets-scan.sh
rmdir kit/hooks kit/tests kit 2>/dev/null || true
```
Update `.secrets-scan-allow` to:
```
# Files that legitimately contain secret-looking fixtures/examples (NOT real secrets).
# Path globs, repo-root-relative, one per line. The secrets-scan hook skips these.
tests/*
home/.claude/hooks/secrets-scan.sh
home/.claude/settings.fragment.json
docs/superpowers/plans/*
```
Confirm the hook still passes from its new location:
`bash tests/test-secrets-scan.sh home/.claude/hooks/secrets-scan.sh` → `PASS=10 FAIL=0`.

- [ ] **Step 2 — Create `home/.claude/CLAUDE.md` = verbatim current global**

```bash
cp ~/.claude/CLAUDE.md home/.claude/CLAUDE.md
```
(The behavioral layer is appended in Task 3. This step just brings the canonical copy into the repo.)

- [ ] **Step 3 — Create `home/.claude/settings.fragment.json`** (only the managed keys; merged into live settings.json, never overwrites his `defaultMode:auto`, plugins, voice, theme):

```json
{
  "permissions": {
    "allow": [
      "Bash(git add *)", "Bash(git commit*)", "Bash(git push*)",
      "Bash(git switch *)", "Bash(git checkout *)",
      "Bash(gh repo create *)", "Bash(gh repo view *)"
    ],
    "deny": ["Read(./.env)", "Read(./.env.*)"]
  },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "if": "Bash(git commit*)", "command": "$HOME/.claude/hooks/secrets-scan.sh" },
        { "type": "command", "if": "Bash(git push*)",   "command": "$HOME/.claude/hooks/secrets-scan.sh" }
      ]}
    ]
  }
}
```

- [ ] **Step 4 — Write the failing installer test** `tests/test-install.sh`

Runs `install.sh` against a SANDBOX (`CLAUDE_HOME=/tmp/...`), never the real `~/.claude`. Asserts: `CLAUDE.md` + `hooks/secrets-scan.sh` become symlinks into the repo; `settings.json` gains the `hooks` block AND preserves a pre-seeded key (e.g. `enabledPlugins`); a backup dir is created for replaced files; a second run is idempotent (no error, links stay correct). Full code:

```bash
#!/usr/bin/env bash
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
pass=0 fail=0; ok(){ echo "ok   - $1"; pass=$((pass+1)); }; no(){ echo "FAIL - $1"; fail=$((fail+1)); }
sb=$(mktemp -d); trap 'rm -rf "$sb"' EXIT
export CLAUDE_HOME="$sb/.claude"; mkdir -p "$CLAUDE_HOME"
# seed a pre-existing settings.json with a key that MUST survive the merge
printf '{"enabledPlugins":{"x":true},"theme":"dark"}\n' > "$CLAUDE_HOME/settings.json"
printf '# old global\n' > "$CLAUDE_HOME/CLAUDE.md"

bash "$REPO/install.sh" >/dev/null 2>&1 || { echo "FAIL: install.sh errored"; exit 1; }

[ -L "$CLAUDE_HOME/CLAUDE.md" ] && [ "$(readlink "$CLAUDE_HOME/CLAUDE.md")" = "$REPO/home/.claude/CLAUDE.md" ] && ok "CLAUDE.md symlinked" || no "CLAUDE.md symlinked"
[ -L "$CLAUDE_HOME/hooks/secrets-scan.sh" ] && ok "hook symlinked" || no "hook symlinked"
jq -e '.hooks.PreToolUse' "$CLAUDE_HOME/settings.json" >/dev/null 2>&1 && ok "settings has hooks" || no "settings has hooks"
jq -e '.enabledPlugins.x==true and .theme=="dark"' "$CLAUDE_HOME/settings.json" >/dev/null 2>&1 && ok "settings preserved pre-existing keys" || no "settings preserved keys"
ls "$CLAUDE_HOME"/backups/*/CLAUDE.md >/dev/null 2>&1 && ok "backed up replaced CLAUDE.md" || no "backup made"
bash "$REPO/install.sh" >/dev/null 2>&1 && ok "idempotent re-run" || no "idempotent re-run"
[ -L "$CLAUDE_HOME/CLAUDE.md" ] && ok "still linked after re-run" || no "still linked after re-run"

echo "----"; echo "PASS=$pass FAIL=$fail"; [ "$fail" -eq 0 ] || exit 1
```
Run it → expect failure (`install.sh` missing).

- [ ] **Step 5 — Write `install.sh`**

```bash
#!/usr/bin/env bash
# install.sh — wire this repo's canonical Claude config into ~/.claude (idempotent).
# Symlinks user-owned files (CLAUDE.md, hooks/); MERGES managed keys into the
# app-owned settings.json (symlinking it is fragile — the app rewrites it).
# Backs up anything it replaces. Re-runnable. CLAUDE_HOME overrides ~/.claude (tests).
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
if ! command -v jq >/dev/null 2>&1; then echo "WARN: jq missing; install jq and re-run to merge settings." >&2; exit 0; fi
if [ -f "$SET" ]; then
  mkdir -p "$BK"; cp "$SET" "$BK/settings.json"
  tmp=$(mktemp); jq -s '.[0] * .[1]' "$SET" "$FRAG" > "$tmp" && mv "$tmp" "$SET"
  echo "merged settings fragment into settings.json (backup: $BK/settings.json)"
else
  cp "$FRAG" "$SET"; echo "created settings.json from fragment"
fi
echo "done.${BK:+ backups in $BK}"
```

- [ ] **Step 6 — Run installer test → expect `PASS=… FAIL=0`; commit**

```bash
chmod +x install.sh tests/test-install.sh tests/test-secrets-scan.sh
bash tests/test-install.sh
git add -A && git commit -m "feat(kit): dotfiles layout + idempotent install.sh (symlink + jq settings merge)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 3 — Behavioral layer into the canonical CLAUDE.md

**Files:** Modify `home/.claude/CLAUDE.md` (append).

- [ ] **Step 1 — Append the autonomy-tuned Karpathy trim** to `home/.claude/CLAUDE.md`:

```markdown

## Coding behavior (agent discipline)
Complements — does not replace — the git/secrets rules above. Bias: reduce costly
mistakes on non-trivial work; on trivial edits, use judgment.

- **Surgical changes.** Touch only what the request requires. Don't "improve" adjacent
  code/comments/formatting; don't refactor what isn't broken; match existing style.
  Remove only orphans *your* change created; flag unrelated dead code, don't delete it.
- **Goal-driven execution.** Turn tasks into verifiable goals and loop until met
  ("fix the bug" → "write a failing test, then make it pass"). Prefer conditions you
  prove by running something (test/lint/build exit code).
- **Simplicity first.** Minimum code that solves the problem; no speculative features,
  single-use abstractions, or unrequested config. If 200 lines could be 50, rewrite.
- **State assumptions, don't stall.** On ambiguity, write the assumption and proceed;
  don't silently guess; block only when the choice is destructive or expensive to reverse.

> The secrets-scan guardrail above is now **enforced** by a PreToolUse hook
> (`~/.claude/hooks/secrets-scan.sh`), not just instruction.
```

- [ ] **Step 2 — Commit** (`feat(kit): add autonomy-tuned behavioral layer to global CLAUDE.md`).

### Task 4 — Activate: run `install.sh` against the real `~/.claude` ⚠️ CONFIRM FIRST

This is the only step that mutates the live global config. It is reversible (backs up to `~/.claude/backups/<ts>/`). **Get Roberto's explicit OK before running.**

- [ ] **Step 1 — Dry context check:** show what exists, confirm `jq` present.
- [ ] **Step 2 — Run `./install.sh`.**
- [ ] **Step 3 — Verify:** `~/.claude/CLAUDE.md` and `~/.claude/hooks/secrets-scan.sh` are symlinks into the repo; `~/.claude/settings.json` now has the `hooks` block AND still has `defaultMode:auto` + all 7 plugins + voice/theme; `settings.local.json` untouched.
- [ ] **Step 4 — Live test in Claude Code:** `/hooks` shows the two PreToolUse entries under `[User]`; staging a fake `sk_live_…` and asking Claude to commit is blocked.

### Task 5 — Reconcile `cc-autopilot.sh` to call the canonical hook (DRY)

- [ ] Replace its inline secret check with a call to `$HOME/.claude/hooks/secrets-scan.sh` (treat a `"deny"` in stdout OR non-zero exit as a block). Verify on a scratch repo (fake secret → refuses; clean → pushes). Commit.

### Note on fixtures
The `.secrets-scan-allow` covers this repo's fixture/doc paths so the hook (once active) never flags them. Add paths there if you later commit the `AgenticInstructions*` research folders.

---

## Phase 1 — Plane 1: Claude Code on the web (runbook)
Log into Claude Code web; connect the `career-ops` GitHub repo; install the mobile app; verify fire-and-review from the phone (Success Criterion #1). Add a per-repo `./CLAUDE.md` to `career-ops` with build/lint/test commands (for Phase 3 `/goal`).

## Phase 2 — Plane 2: VPS engine room
Now simplified by Option B: **provision Hetzner CX22 → clone this repo → run `install.sh` → identical brain.** Then: security hardening (SSH key-only, ufw, Tailscale/WireGuard, fail2ban or SSH off :22, no blind `--dangerously-skip-permissions`); `claude-code-router` + current slugs + OpenRouter key (DeepSeek bulk-scoring only); `tmux`/`mosh` + Termius; the branch→Vercel-preview→merge gate (F5); on-demand then one `cron` for the morning pipeline, digests pushed to the repo. *(Own dated plan at execution; needs §11.1 confirm.)*

## Phase 3 — 24-7 agentic usage layer (built-in; learning)
`/goal` with conditions proven by running (test/lint/build exit), auto mode (already on — `defaultMode:auto`), `claude agents`/`/bg` for parallel fire-and-review, a stop hook gating "done" on a real check, `/schedule` for cloud routines + `cron` for the VPS pipeline. Needs Claude Code ≥ v2.1.139 for `/goal`.

## Phase 4 — Experiment: RTK (reversible)
Install; `rtk init --show` to confirm its hook sits *alongside* the secrets hook (scan first, then rewritten push); sanity-test the scan still blocks; measure `rtk gain`; keep or `rtk init -g --uninstall`.

## Phase 5 — Capstone: author the `/audit` skill (career track)
From the F3 draft; fill the two `<FILL IN>` blocks by reading 2–3 past audits; set the Notion destination; run on one live target; tighten.

## Deferred
- **claude-mem** (native memory covers it; revisit on visible failure). **product-pulse** (product-side, out of scope).

---

## Self-review
- Option B is consistent: install.sh symlinks user-owned files, merges app-owned settings, preserves `settings.local.json`; the hook path `$HOME/.claude/hooks/secrets-scan.sh` is identical in the fragment, Task 5, and Phase 4. ✔
- Task 1 done; Tasks 2–3 are repo-side (safe, reviewed); Task 4 is the single gated global mutation (reversible via backups). ✔
- Spec §11 resolved; success criteria mapped (#1→P1, #2→P2, #3→P2, #4→P2, #5→P2 hardening). ✔
