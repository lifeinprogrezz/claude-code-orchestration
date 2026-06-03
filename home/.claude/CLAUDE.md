# Global preferences (~/.claude/CLAUDE.md)

> Canonical copy lives in the Orchestration repo at `home/.claude/CLAUDE.md`, symlinked to `~/.claude/CLAUDE.md`. Edit it in the repo — changes are version-controlled and apply on every machine where `install.sh` has run.

## Identity
Git author: lifeinprogrezz <hello@lifeinprogrezz.com>

## Commit style
- Conventional Commits: `type(scope): description`
- Imperative mood, subject ≤72 chars
- Types I use: feat, fix, refactor, docs, chore, test, style
- Commit autonomously when a discrete unit of work completes (a feature, a fix, a refactor) — don't wait for me to prompt

## Git autonomy
- For projects meant to be tracked: initialize git, create a `.gitignore` (minimum: `.DS_Store`, `*.log`, `node_modules/`, `.env`, `.env.local`, `dist/`, `build/`), and create the private GitHub remote via `gh repo create <name> --private --source=. --push` in the same pass
- Push to remote after every commit; no need to ask
- Skip all git setup for throwaway work in `/tmp`, `~/scratch`, or anything I label as a one-off
- **One guardrail:** before any push, grep staged files for obvious secrets (`.env*` content, lines matching `(api[_-]?key|secret|token|password)\s*=`, AWS-style key patterns). If anything matches, stop and surface it instead of pushing.

## Mid-session persistence (universal)
When we agree on something durable mid-conversation — a template, scoring rule, column spec, diagnostic framework, calibration, or prompt — write it to a file IMMEDIATELY, in the same turn. Don't batch to end of session.

The laptop can close abruptly (battery, distraction). Anything that needs to survive must already be on disk by then.

## At session start
Sweep ALL memory files under `~/.claude/projects/<project-slug>/memory/`, not just `MEMORY.md`'s index. The index lags behind file contents; individual files often hold durable decisions the index hasn't yet pointed to.

If unsure which slug corresponds to the current project, run `/memory` first to surface the loaded paths.

## Session wrap-up

When I signal end-of-session — by saying "wrap up", "save before I close", or any equivalent — run the following procedure in order, then stop. Chat transcripts don't persist between sessions; files, memory, and CLAUDE.md do.

### 1. Session log entry
Append a dated entry to the project's session log under a `## YYYY-MM-DD — open threads + decisions` heading. Cover:
- **Decided** — durable conclusions, not ephemeral thinking
- **In the air** — open threads that didn't resolve
- **Next session** — the first thing to pick up

Log file location:
- If the project root's `CLAUDE.md` names a session log (e.g. `TRIAL_NOTES.md` for career-ops), use that file
- Otherwise create one at the project root named `SESSION_LOG.md`

### 2. Auto-memory updates
Open the project's memory dir at `~/.claude/projects/<project-slug>/memory/` and:
- Add new project-memory entries for in-flight work or shifts in plan
- Add new feedback-memory entries for durable preferences or calibrations from this session
- Update existing memory files that have drifted; remove stale ones
- Update `MEMORY.md` so its index reflects any new pointers

If unsure which slug corresponds to this project, run `/memory` first to confirm the loaded paths.

### 3. Persist sketched artifacts
Any durable artifact we sketched in chat — templates, scoring rules, column specs, diagnostic frameworks, prompts, schemas — write to an appropriate project file now. Nothing durable should be left only in chat.

### 4. Commit and push outstanding work
Run `git status`. Group the modified/untracked files by logical unit and commit each group with a Conventional Commit message. Then push.

Apply the secrets-scan guardrail from the Git autonomy section before pushing. If you deliberately leave anything uncommitted (half-finished experiment, scratch file), call it out explicitly in the summary below.

### 5. Confirm with a 3-line summary
Reply with exactly three lines:
- **Saved & pushed:** [commits made + files persisted this turn]
- **Pending:** [what's still in flight or deliberately uncommitted]
- **Next session:** [the first thing to pick up]

Then stop. Let me close the laptop.

## Coding behavior (agent discipline)
Complements — does not replace — the git/secrets rules above. Bias: reduce costly
mistakes on non-trivial work; on trivial edits, use judgment.

- **Surgical changes.** Touch only what the request requires. Don't "improve" adjacent
  code/comments/formatting; don't refactor what isn't broken; match existing style.
  Remove only orphans *your* change created; flag unrelated dead code, don't delete it.
- **Goal-driven execution.** Turn tasks into verifiable goals and loop until met
  ("fix the bug" -> "write a failing test, then make it pass"). Prefer conditions you
  prove by running something (test/lint/build exit code).
- **Simplicity first.** Minimum code that solves the problem; no speculative features,
  single-use abstractions, or unrequested config. If 200 lines could be 50, rewrite.
- **State assumptions, don't stall.** On ambiguity, write the assumption and proceed;
  don't silently guess; block only when the choice is destructive or expensive to reverse.

> The secrets-scan guardrail above is now **enforced** by a PreToolUse hook
> (`~/.claude/hooks/secrets-scan.sh`), not just instruction.
