# Two-Plane Claude Ecosystem — Design Spec

- **Date:** 2026-05-28
- **Owner:** Roberto Quintero (lifeinprogrezz)
- **Status:** Approved — pending implementation plan
- **Location of this work:** `~/Documentos/Coding/Orchestration` (the *ecosystem* repo)

## 1. Purpose

Set up a working environment that lets Roberto **develop and run his `career-ops` job-search
product from his phone** — editing code, running the pipeline, judging the output, and letting
agents work while he is away — **without the laptop open**, and **with model capacity beyond his
subscription quota**.

This folder delivers the *ecosystem* only. The actual product (turning `career-ops` +
auditjob.me into a multi-user web app) is built **later, in its own repo, using this ecosystem.**
Nothing in this spec builds the product.

## 2. Context

- `career-ops` is a mature single-user CLI (~60 scripts: scan → score → triage → digest →
  applications tracking; ~10K live jobs; CV/cover-letter generation). It runs from one command,
  `npm run morning`, and is driven today from a terminal with markdown output read in chat.
- The pain point: it is powerful but lives in a terminal, tied to an open laptop.
- Roberto wants to (a) iterate on it from his phone, (b) have agents keep working while he is
  away, and (c) run it at a usage volume his subscription quota will not cover.
- A prior claude.ai conversation produced a VPS "remote ops kit" (the 6 files already in this
  folder: `bootstrap.sh`, `ccr-config.json`, `ccr.service`, `cc-autopilot.sh`, `README.md`, plus
  two `.odt` transcripts). This design **refines and repurposes that kit** rather than starting over.

## 3. The core constraint that shapes everything: two auth planes

Claude Code authenticates on one of two planes, and they do not mix:

| Plane | Entered by | Billing | Can add API/router/other providers? |
|-------|-----------|---------|-------------------------------------|
| **Subscription** | `claude` / Claude Code on the web (OAuth) | Pro/Max quota (rolling windows) | **No** — managed, subscription-locked |
| **Router / API** | `ccr code`, or `ANTHROPIC_BASE_URL`/`ANTHROPIC_API_KEY` | metered API credits, multi-provider | **Yes** |

Consequence: **Claude Code on the web cannot be given extra capacity** beyond a bigger
subscription tier — you cannot bolt your own API keys, a router, or other providers onto the
managed cloud. Real extra capacity (pay-as-you-go API, multiple providers, cheap-model bulk
routing) only exists on **a machine you control**. To serve Roberto *while he is away*, that
machine must be **always on** — hence a small VPS.

This is why the design has two planes.

## 4. Architecture

### Plane 1 — Claude Code on the web (subscription) · *your hands*
- Driven from the iOS/Android app; connected to the GitHub repo.
- Used for **writing code**: edit the scoring algorithm, fix bugs, add features.
- Supports firing one or several tasks in parallel, then reviewing later ("fire-and-review").
- No API keys, no server, zero ops. Writing code needs no secrets, so nothing sensitive ever
  reaches the managed cloud.

### Plane 2 — small always-on VPS + router (~€5/mo) · *your engine room*
- Runs `claude-code-router` → **multiple providers**: Anthropic API primary, OpenRouter/DeepSeek
  for cheap **bulk scoring** (mirrors what `career-ops` already does via its `--backend
  openrouter` scripts). This is the answer to "subscription won't be enough."
- Holds the API keys and the scan session; runs the pipeline (`morning`, or just
  score → triage → digest) **on demand or on a schedule**.
- Reached from the phone via **Remote Control** into a `tmux` session — run the pipeline and read
  the digest right there. Scheduled runs push their output to the repo so it is always readable
  from the phone (GitHub mobile or a web session).
- Headless autonomous runs use `cc-autopilot.sh` with the **secret-scan-before-push** guardrail.

### Two mobile mechanisms, split by job
- **Claude Code on the web** → writing code (no environment needed).
- **Remote Control into the VPS** → running and reading the pipeline (where the env/keys live).

### The iteration loop this unlocks (clarifications #1 + #2 + #3)
From the phone: tweak scoring (Plane 1) → re-run on the VPS (Plane 2) → read the new ranking →
judge → tweak again. Plus the VPS doing scheduled/autonomous runs reviewed on mobile or next
laptop session.

### What runs where (the secrets rule)
- **Code-writing** → Plane 1 (cloud), never needs keys.
- **Pipeline execution** → Plane 2 (VPS), where keys live. Keys never go to the managed cloud.
- The full LinkedIn-authenticated scan is fragile off the laptop; the runnable-from-anywhere,
  judgeable part is **score → triage → digest** on already-scanned jobs (API key only).

## 5. Deliverables of this folder

1. **Setup walkthrough** — the interactive steps Roberto runs himself:
   - Plane 1: log into Claude Code on the web, connect GitHub, install the mobile app.
   - Plane 2: provision the VPS, run the refined `bootstrap.sh`, add the OpenRouter key, harden
     security, set up the Remote Control `tmux` session + optional `cron`.
2. **"How I work" playbook** — when to use web (Plane 1) vs Remote-Control-into-VPS (Plane 2);
   the keys-stay-on-the-VPS rule; the scoring-iteration loop; task-shapes worth delegating.
3. **Refined kit** — update the existing 6 files:
   - Bump stale model slugs (e.g. `claude-opus-4.6` → current Opus/Sonnet).
   - Keep DeepSeek **only for bulk scoring**, not as orchestrator (cheap capacity is now the
     explicit goal; Claude stays the orchestrator).
   - Wire `cc-autopilot.sh` + `cron` for scheduled autonomous runs.
4. **Security hardening checklist** — SSH key-only (no password auth), firewall/Tailscale or
   WireGuard rather than open public SSH, careful key handling, and **no blind
   `--dangerously-skip-permissions`** on a box that holds push credentials and API keys.

## 6. Security model

The VPS will hold the OpenRouter key (plaintext in `~/.claude-code-router/config.json`), the
Anthropic credential, and push access to repos. It is therefore a high-value target. The existing
kit only guards the *commit path* (secret-scan-before-push). This design adds box-level hardening
as a **mandatory, non-optional** deliverable (see §5.4). Autonomous runs keep scoped
`--allowedTools`; the full-bypass mode is not used on a credential-bearing box.

## 7. Costs and commitments (honest)

- ~€5/mo VPS (Hetzner; Barcelona-friendly latency).
- Pay-as-you-go OpenRouter credits (scales with usage; cheap-model bulk routing keeps it low).
- A one-time security setup (the real homework).
- Occasional model-slug upkeep as OpenRouter slugs rotate.
- Claude does nearly all setup and upkeep; Roberto does the logins, the VPS provisioning commands
  (guided), and executes the hardening checklist.

## 8. Roles

- **Claude:** writes all docs/config in this folder; refines the kit; guides every interactive step.
- **Roberto:** performs account/GitHub/app logins and VPS provisioning commands (cannot be done
  for him); executes the security hardening checklist.

## 9. Goals / Non-goals

**Goals**
- Edit `career-ops` code from the phone (Plane 1).
- Run the pipeline and read its output from the phone (Plane 2 via Remote Control + pushed digests).
- Autonomous/scheduled runs reviewable on mobile or next laptop session.
- Model capacity beyond subscription via multi-provider router (Plane 2).
- Keys never leave a machine Roberto controls.

**Non-goals (explicitly out of scope)**
- Building the multi-user product (separate repo, later).
- Codebase cleanup of `career-ops` beyond what the kit needs.
- Running the LinkedIn-authenticated scan in the managed cloud.
- Full unattended `--dangerously-skip-permissions` autopilot on the credential-bearing box.

## 10. Success criteria

1. From the phone, Roberto can open a Claude Code web session on the repo, edit the scoring code,
   and fire a task he reviews later.
2. From the phone, Roberto can trigger a `score → triage → digest` run on the VPS and read the
   resulting ranking.
3. A scheduled VPS run produces output Roberto can review on mobile without touching the laptop.
4. Heavy usage routes through the API/multi-provider plane, not blocked by subscription windows.
5. The VPS passes the security hardening checklist before holding any real key.

## 11. Open items for the implementation plan

- Exact VPS provider/region/size and provisioning steps.
- Whether/how to give the VPS a usable scan session (LinkedIn cookies) vs. score-only on
  laptop-produced data.
- Scheduling shape: on-demand only, fixed `cron`, or native Claude scheduling.
- How pushed digests are surfaced on mobile (GitHub app vs. a tiny static render).
- Current correct model slugs at implementation time.
