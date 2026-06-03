# Claude orchestration — my two-plane Claude Code ecosystem

This repo is the **canonical, version-controlled home of my Claude Code setup** — not a
product. It does two things:

1. **Dotfiles foundation** (`home/.claude/` + `install.sh`): my global `CLAUDE.md`, the
   secrets-scan enforcement hook, and the managed settings, installed by symlink/merge
   onto any machine (laptop **and** VPS) so they behave identically.
2. **Remote ops kit** (`bootstrap.sh`, `ccr-*`, `cc-autopilot.sh`, `harden-vps.sh`): turns a
   small VPS into an always-on, phone-controlled Claude Code agent with cost-aware model
   routing and an autonomous lane that can't leak secrets.

## Layout
```
home/.claude/                 # canonical ~/.claude config — install.sh wires it in
├── CLAUDE.md                 #   global instructions + coding-behavior layer   → symlinked
├── hooks/secrets-scan.sh     #   PreToolUse secrets gate (fail-closed)          → symlinked
└── settings.fragment.json    #   managed keys (hooks + git/gh perms)            → jq-merged
install.sh                    # idempotent: backup + symlink + merge (CLAUDE_HOME overridable)
tests/                        # test-secrets-scan.sh (10 cases), test-install.sh
.secrets-scan-allow           # per-repo allowlist of paths the hook skips
bootstrap.sh                  # VPS: Node+claude+ccr, runs install.sh, wires the service
harden-vps.sh                 # VPS: ufw + fail2ban + (guarded) key-only SSH
ccr-config.json / ccr.service # claude-code-router config + systemd user unit
cc-autopilot.sh               # headless `claude -p` wrapper; pushes only if the hook passes
docs/superpowers/             # design spec + implementation plan + the VPS runbook
```

## Install the foundation (any machine)
```bash
git clone https://github.com/lifeinprogrezz/claude-orchestration.git ~/orchestration
cd ~/orchestration
./install.sh        # symlinks ~/.claude/{CLAUDE.md,hooks/secrets-scan.sh}, merges settings.json
                    # (backs up anything it replaces to ~/.claude/backups/<ts>/; needs jq)
```
It preserves everything already in your `settings.json` and never touches `settings.local.json`.
On the VPS, `bootstrap.sh` runs `install.sh` for you.

## The one thing to understand: two planes
Claude Code authenticates on one of two planes, and they don't mix.

| Plane | Enter it by | Uses | Failover |
|------|-------------|------|----------|
| **Subscription** | `claude` (OAuth) | Max quota (rolling windows) | none — blocked when the window closes |
| **Router / API** | `ccr code`, or `ANTHROPIC_BASE_URL`/`ANTHROPIC_API_KEY` | metered API credits via OpenRouter | yes — multi-provider, cheap-model background routing |

You run **two modes** and flip with one command: `claude` (daily driver, best value) vs
`ccr code "..."` (overflow/autopilot, cost-routed). Keys only ever live on a machine you
control (the VPS) — never in this repo, never on the managed cloud.

## VPS setup
Full step-by-step (provision → harden → bootstrap → keys → remote control → cron) is in
**`docs/superpowers/plans/2026-05-30-phase2-vps-runbook.md`**. Short version:
```bash
# on the VPS, after adding your SSH key:
git clone … ~/orchestration && cd ~/orchestration
./harden-vps.sh && ./harden-vps.sh --ssh    # then Tailscale
./bootstrap.sh                              # installs everything + runs install.sh
nano ~/.claude-code-router/config.json      # add the real OpenRouter key; restart ccr
```

## Remote control (phone)
```bash
tmux new -s cc            # mosh first if you roam between networks
claude --remote-control   # scan the QR once;  detach: Ctrl-b d ;  reattach: tmux attach -t cc
```

## Autopilot (cron)
`cc-autopilot` runs a task headless, then pushes **only if the canonical secrets-scan hook
passes** (same hook as interactive Claude Code; honours each repo's `.secrets-scan-allow`).
```cron
30 7 * * 1-5  USE_ROUTER=1 /home/you/.local/bin/cc-autopilot /home/you/career-ops "run morning; commit the digest"
```

## Secrets gate
`home/.claude/hooks/secrets-scan.sh` blocks any `git commit`/`git push` whose diff looks like
credentials (`.env` files, `key/secret/token/password = …`, Stripe/GitHub/Slack/AWS/PEM
prefixes). **Fails closed** on internal error. False positive on a legit fixture/doc? Add its
path to that repo's `.secrets-scan-allow`. Never put a real key in a tracked file.

## Health checks
```bash
ccr status   •   systemctl --user status ccr   •   claude doctor
bash tests/test-secrets-scan.sh home/.claude/hooks/secrets-scan.sh   # PASS=10
```
