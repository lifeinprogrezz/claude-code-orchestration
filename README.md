> **Generated.** This repo is the output of `tools/export-work-kit.sh` in a private
> orchestration repo. Do not edit files here; a re-export overwrites them. Improvements go to
> `FOLLOWUPS.md` and travel back by hand. It is also a public showcase of how I run Claude Code.

# Claude Code work kit — the portable method

One clone plus `./install.sh` puts my working method on any Linux or WSL machine:
always-loaded doctrine, two enforcement hooks, two writing/research skills, and two ledger
templates. It contains no personal data, no credentials and nothing about any employer. A gate in
the exporter fails the build otherwise.

## Install (Linux / WSL; needs `git` and `python3`; `jq` optional)
```bash
git clone https://github.com/lifeinprogrezz/claude-code-orchestration.git ~/orchestration
cd ~/orchestration
./install.sh
```
`install.sh` is idempotent. It:
- symlinks `~/.claude/CLAUDE.md`, `~/.claude/hooks/*.sh` and `~/.claude/skills/<name>` into this clone;
- **preserves a pre-existing `~/.claude/CLAUDE.md`** as `~/.claude/CLAUDE.local.md` (the kit's
  CLAUDE.md imports it at the end, so your own profile keeps loading);
- merges `home/.claude/settings.fragment.json` into `~/.claude/settings.json` (hooks, two git
  permissions, five plugins) with `jq` or, if missing, `python3`. Everything else in your settings
  is preserved; `settings.local.json` is never touched;
- asserts every wired hook and managed skill is deployed.

Update: `cd ~/orchestration && git pull && ./install.sh`.

## What it installs
| Piece | What it does |
|---|---|
| `home/.claude/CLAUDE.md` | Doctrine: coding behavior, session ritual, 9 operating pillars, STE writing rules, work profile |
| `hooks/secrets-scan.sh` | PreToolUse gate on `git commit`/`git push`. Blocks credential-looking diffs. Fails closed |
| `hooks/claude-md-size.sh` | PostToolUse warning when a CLAUDE.md or MEMORY.md crosses its auto-load budget |
| `skills/ste-writing` | ASD-STE100 anti-slop writing skill + `ste-lint.py` |
| `skills/reverse-engineering-competitors` | First-hand product teardown method |
| `templates/ledgers/` | `decisions.md` (append-only) and `discrepancies.md` (corrections are law) for any project brain |
| `tools/redact-secrets.py` | Scrub secret-shaped values from generated text before it enters git |
| `BOOTSTRAP.md` | The steps a Claude Code session runs to adopt the kit in a project |

## What it deliberately does not contain
Identity, accounts, project pointers, remote-ops tooling, router config, personal skills,
session logs, research notes. See the exporter's allowlist in the private repo.

## Verify
```bash
bash tests/test-secrets-scan.sh home/.claude/hooks/secrets-scan.sh   # PASS=10
bash tests/test-install.sh
bash tests/test-redact-secrets.sh
```
Then, in any git repo: stage a scratch file holding a fake live-mode Stripe-style key (see `BOOTSTRAP.md`
step 5), ask Claude Code to commit, expect BLOCKED, delete the file.

If your organization pushes managed settings (`/etc/claude-code/managed-settings.json`), those
win over `settings.json`. Confirm the hooks still fire after install.

## Boundary rule
Nothing employer-specific goes into this kit. Nothing personal goes into an employer workspace.
Employer context lives in the employer project; the kit is method only.
