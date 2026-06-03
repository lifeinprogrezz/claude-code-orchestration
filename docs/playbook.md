# How I work — the 24/7 agentic layer (Phase 3)

Operating manual for driving the two-plane ecosystem once it's live. Most of this is
**built into Claude Code** — nothing to install; the point is knowing when to reach for what.

## Which plane, when
- **Plane 1 (web / `claude`, subscription):** writing code, fire-and-review. Best value; no keys.
- **Plane 2 (`ccr code`, API/router):** overflow when the Max window is spent, bulk scoring
  (DeepSeek), and scheduled/headless runs. Keys live here only.
- Flip with the command you run — there's no auto-failover between planes (different auth).

## `/goal` — loop until verified (the Ralph loop, built in)
Set a completion condition Claude **proves by running something**; it keeps working until met.
```
/goal npm test exits 0 and `next build` is clean
```
The evaluator (a fast model) only judges what's in the transcript — so never write
"the feature feels done"; write conditions backed by a test/lint/build **exit code**.
Needs Claude Code ≥ v2.1.139 (`claude --version`).

## auto mode — already on
`settings.json` has `defaultMode:"auto"` (+ `skipAutoPermissionPrompt`), so Claude runs tools
without per-call approval. The **secrets-scan PreToolUse hook is the safety gate** that makes
this safe — it can't be skipped by auto mode. (Toggle per-session with shift+tab.)

## agent view — parallel fire-and-review
`claude agents` shows all sessions in one list; `/bg` backgrounds the current one;
`claude --bg "task"` launches a fresh background session. Use it to run several chunky,
independent jobs at once (e.g. multiple audits/builds) and review the finished set — instead of
a tmux grid + a mental ledger. Only worth it for jobs big enough to run async.

## `/loop` and `/schedule`
- `/loop` — grind a refactor/cleanup backlog.
- `/schedule` — cloud routines (laptop shut). For the VPS pipeline prefer a plain `cron`
  (runs where the keys are); see the VPS runbook.

## stop hook — gate "done" on a real check (optional, per-project)
A `Stop` hook can refuse to let Claude finish until a check passes. Template — wire it in a
project's `.claude/settings.json`, pointed at a script like:
```bash
#!/usr/bin/env bash
# stop-gate.sh — exit non-zero (with a reason on stderr) to keep Claude working.
npm run lint >/dev/null 2>&1 || { echo "lint failing — keep going" >&2; exit 2; }
npm test     >/dev/null 2>&1 || { echo "tests failing — keep going" >&2; exit 2; }
exit 0
```
Keep checks fast and deterministic, or it slows every turn. (`/goal` covers most cases without
a standing hook — reach for the stop hook only when you want it enforced on every session.)

## The deploy gate (don't skip on max-agency)
Auto-push + Vercel-auto-deploy-`main` = "agent ships to prod unreviewed." Instead: agent pushes
to a **branch** → Vercel builds a **preview** → you merge to prod from the phone.

## Later (earmarked, not yet done)
- **Phase 4 — RTK** (context/token compressor): a reversible 10-min trial *after* the VPS is up.
  `curl … | sh; rtk init -g`, then `rtk init --show` to confirm its hook sits **alongside** (not
  replacing) the secrets hook — scan first, then the rewritten push. Sanity-test the scan still
  blocks; keep if `rtk gain` is real, else `rtk init -g --uninstall`. Awaiting your go.
- **Phase 5 — `/audit` skill** (career track, off the ecosystem axis): scaffold exists in
  `AgenticInstructions3/SKILL.md` with two `<FILL IN>` blocks (your exact output template +
  Notion destination) only you can fill. Build it by pointing Claude at 2–3 past audits to
  extract your real structure, then run on one live target.
