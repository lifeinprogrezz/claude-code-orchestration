# "When you're home" runbook — Planes 1 & 2 (the manual steps)

Phase 0 (the dotfiles foundation) is **done + live + pushed**. This runbook is the
ordered set of steps that need *your* hands (accounts, payment, SSH/VPN, logins) —
everything else (hook, install.sh, kit, harden script) is already built and in the repo.
Recommended defaults are pre-filled; change any and tell me to re-codify.

Legend: 🧑 = you must do it · 🤖 = I can finish/automate once you've made the call · ⏱ ≈ time.

---

## 0. Decisions to confirm (2 min) 🧑
- **VPS:** Hetzner **CX22** (2 vCPU / 4 GB, ~€4–5/mo), region **Nuremberg** or **Falkenstein** (EU; ~40–60 ms from Barcelona). Go **CX32 (8 GB)** only if you'll run the dev server + builds + a DB on it at once.
- **VPN:** **Tailscale** (easiest; free tier fine) over raw public SSH. WireGuard if you prefer manual.
- **What runs on the VPS v1:** `score → triage → digest` on laptop-produced data. The LinkedIn-authenticated scan stays on the laptop for now.

## 1. Plane 1 — Claude Code on the web (10 min) 🧑
1. Open Claude Code on the web, sign in (your Max plan).
2. Connect the **career-ops** GitHub repo.
3. Install the Claude iOS/Android app; sign in.
4. **Test (Success Criterion #1):** from the phone, open a web session on the repo, make a tiny scoring-code edit, fire it, review later. ✅ when that round-trips.
5. 🤖 *Already prepped:* drop `templates/career-ops.CLAUDE.md` (in this repo) into `career-ops/CLAUDE.md` so `/goal` knows its build/lint/test commands. (Adjust the commands to match the repo, or tell me the repo layout and I'll tailor it.)

## 2. Plane 2 — provision the VPS (10 min) 🧑
1. Create the Hetzner CX22 (Ubuntu 24.04 LTS), region as above. Add your SSH public key during creation.
2. From your laptop, confirm key login:  `ssh <user>@<vps-ip>`  (no password prompt = key works).
3. Create a non-root sudo user if Hetzner gave you root only:
   ```bash
   adduser rober && usermod -aG sudo rober
   mkdir -p /home/rober/.ssh && cp ~/.ssh/authorized_keys /home/rober/.ssh/ && chown -R rober:rober /home/rober/.ssh
   ```

## 3. Harden BEFORE any key lands (5 min) 🧑 — spec §6, mandatory
On the VPS, in **two** terminals (so you can't lock out):
```bash
git clone https://github.com/lifeinprogrezz/claude-orchestration.git ~/orchestration
cd ~/orchestration
./harden-vps.sh            # ufw + fail2ban + auto security updates (safe)
# confirm a NEW key login works in the 2nd terminal, THEN:
./harden-vps.sh --ssh      # disables password/root SSH (guarded; refuses if no authorized_keys)
```
Then Tailscale (recommended):
```bash
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up
# once the tailnet works: restrict SSH to it and drop public SSH
sudo ufw allow in on tailscale0 to any port 22
sudo ufw delete allow OpenSSH
```

## 4. Install the brain (5 min) 🤖-built, you run
```bash
cd ~/orchestration
./bootstrap.sh             # Node(nvm) + claude-code + claude-code-router + jq,
                           # runs install.sh (symlinks CLAUDE.md + secrets hook, merges settings),
                           # wires the ccr systemd service + cc-autopilot on PATH
```
Verify the foundation came across identically:
```bash
ls -l ~/.claude/CLAUDE.md ~/.claude/hooks/secrets-scan.sh   # both symlinks into ~/orchestration
bash ~/orchestration/tests/test-secrets-scan.sh ~/.claude/hooks/secrets-scan.sh   # PASS=10
```

## 5. Keys + model routing (5 min) 🧑 then 🤖
1. Add your **OpenRouter** key (the ONLY place a real key goes — gitignored, never committed):
   ```bash
   nano ~/.claude-code-router/config.json   # replace <OPENROUTER_API_KEY> with the real key
   ```
2. ⚠️ **Verify model slugs** at <https://openrouter.ai/models> — the repo has current-as-of-build
   guesses (`anthropic/claude-opus-4.8`, `anthropic/claude-sonnet-4.6`, `deepseek/deepseek-chat`).
   Fix any that 404, then `systemctl --user restart ccr`.
3. Authenticate Claude on the box:  `claude`  (OAuth = your Max subscription, the daily driver).
4. 🤖 Tell me the real slugs once verified and I'll lock `ccr-config.json` to them.

## 6. Remote control from the phone (5 min) 🧑
```bash
tmux new -s cc          # (or: mosh <user>@<vps> then tmux — mosh survives IP changes on mobile)
claude --remote-control # scan the QR in the Claude app once;  detach: Ctrl-b d
```
**Test (Success Criterion #2):** from the phone, trigger `score → triage → digest` and read the ranking.

## 7. Scheduling + the deploy gate (🤖 once the box exists)
- **Cron** the morning pipeline (after on-demand is proven). I'll write the exact crontab; sketch:
  ```cron
  30 7 * * 1-5  USE_ROUTER=1 /home/rober/.local/bin/cc-autopilot /home/rober/career-ops "run morning: score, triage, digest; commit the digest"
  ```
  The digest is pushed to the repo → readable from the GitHub mobile app (Success Criterion #3).
- **Deploy gate (don't skip):** have the agent push to a **branch**, let Vercel build a **preview**, and you merge to prod from the phone. Never auto-push to a branch Vercel ships to prod. (auditjob.me / career-ops web later.)

## Verification checklist (the spec's success criteria)
- [ ] #1 Edit career-ops from the phone (Plane 1), fire-and-review.
- [ ] #2 Trigger `score→triage→digest` on the VPS from the phone, read the ranking.
- [ ] #3 A scheduled VPS run produces a digest you review on mobile, laptop shut.
- [ ] #4 Heavy use routes through the API/multi-provider plane (`ccr code`), not blocked by subscription windows.
- [ ] #5 The VPS passed `harden-vps.sh` (+ Tailscale) before any key landed.

## Repo artifacts this runbook uses
`bootstrap.sh` · `install.sh` · `harden-vps.sh` · `ccr-config.json` · `ccr.service` · `cc-autopilot.sh` · `home/.claude/{CLAUDE.md,hooks/secrets-scan.sh,settings.fragment.json}` · `tests/`

## Left to decide-then-codify (tell me, I'll build)
- Exact OpenRouter slugs (after you verify them live).
- The morning-pipeline cron line (after I see career-ops' actual `npm run morning` wiring).
- Whether the VPS later gets a LinkedIn scan session (v2) vs. score-only (v1).
