#!/usr/bin/env bash
# bootstrap — set up Claude Code + claude-code-router as an always-on remote agent.
# Target: Debian 10+/Ubuntu 20.04+. Safe to re-run.
set -euo pipefail
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "==> Claude remote ops kit — bootstrap"

# 1) Node 18+ via nvm (no sudo; avoids global-npm permission pain)
need_node=1
if command -v node >/dev/null 2>&1; then
  [ "$(node -p 'process.versions.node.split(".")[0]')" -ge 18 ] && need_node=0
fi
if [ "$need_node" -eq 1 ]; then
  echo "==> Installing Node LTS via nvm…"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"; nvm install --lts
fi
export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# 2) Claude Code + claude-code-router
echo "==> Installing claude-code and claude-code-router…"
npm install -g @anthropic-ai/claude-code@latest
npm install -g @musistudio/claude-code-router@latest

# 2b) jq + wire the canonical Claude config (CLAUDE.md, secrets-scan hook, settings) into ~/.claude
command -v jq >/dev/null 2>&1 || { echo "==> Installing jq (install.sh needs it)…"; sudo apt-get update -qq && sudo apt-get install -y jq; }
echo "==> Wiring dotfiles into ~/.claude via install.sh…"
bash "$KIT_DIR/install.sh"

# 3) Router config (don't clobber an existing one)
mkdir -p "$HOME/.claude-code-router"
if [ ! -f "$HOME/.claude-code-router/config.json" ]; then
  cp "$KIT_DIR/ccr-config.json" "$HOME/.claude-code-router/config.json"
  echo "==> Installed ccr config — EDIT IT to add your OpenRouter key"
else
  echo "==> ccr config already present — left untouched"
fi

# 4) systemd --user service so the router survives reboots and logouts
mkdir -p "$HOME/.config/systemd/user"
cp "$KIT_DIR/ccr.service" "$HOME/.config/systemd/user/ccr.service"
loginctl enable-linger "$USER" || true     # run user services without an active login session
systemctl --user daemon-reload
systemctl --user enable --now ccr.service || echo "warn: edit config then: systemctl --user restart ccr"

# 5) autopilot on PATH
install -Dm755 "$KIT_DIR/cc-autopilot.sh" "$HOME/.local/bin/cc-autopilot"

cat <<'NEXT'

Done. Next steps:
  1) Add your OpenRouter key:   nano ~/.claude-code-router/config.json
                                systemctl --user restart ccr
  2) Authenticate Claude:       claude            (OAuth = your subscription)
                                # or: export ANTHROPIC_API_KEY=sk-ant-...   (API/credit plane)
  3) Remote-control session:    tmux new -s cc
                                claude --remote-control     # scan the QR once, then Ctrl-b d
  4) Autopilot (cron):          see README.md

Sanity checks:  ccr status   •   claude doctor   •   systemctl --user status ccr
NEXT
