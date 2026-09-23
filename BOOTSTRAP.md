# BOOTSTRAP — adopt the kit on this machine

For the Claude Code session on the work machine. Inspect the clone; do not paraphrase it.
Each step: the command, then why. Report each result in one line.

1. **Install.**
   ```bash
   git clone https://github.com/lifeinprogrezz/claude-code-orchestration.git ~/orchestration
   cd ~/orchestration && ./install.sh
   ```
   Why: symlinks the doctrine, hooks and skills; moves the existing `~/.claude/CLAUDE.md` to
   `~/.claude/CLAUDE.local.md` (still loaded, via import); merges settings with python3.

2. **Prove the pieces.**
   ```bash
   bash tests/test-secrets-scan.sh home/.claude/hooks/secrets-scan.sh   # expect PASS=10
   bash tests/test-install.sh && bash tests/test-redact-secrets.sh
   ```
   Why: the hook and the installer are test-pinned; a red test here means stop.

3. **Ledgers in the notes repo.** In the project that holds notes and synthesis:
   ```bash
   cp ~/orchestration/templates/ledgers/decisions.md     notas/decisiones.md
   cp ~/orchestration/templates/ledgers/discrepancies.md notas/discrepancias.md
   printf '# secrets-scan allowlist: individual fixtures only, never a directory\n' > .secrets-scan-allow
   ```
   Then add to the project `CLAUDE.md`, under its always-loaded section:
   ```
   @notas/decisiones.md
   @notas/discrepancias.md
   ```
   Why: decisions are append-only (a change is a new entry that supersedes the old); corrections
   are law (a wrong value that reappears is reverted by the ledger). The wiki mirror already
   documents which spaces are canonical; that content belongs in `discrepancias.md`.

4. **Scrub the mirror at the build boundary.** In the script that regenerates the wiki mirror,
   pass every page body through the redactor before writing markdown:
   ```python
   import subprocess
   body = subprocess.run(["python3", os.path.expanduser("~/orchestration/tools/redact-secrets.py")],
                         input=body, capture_output=True, text=True, check=True).stdout
   ```
   Then once, over the existing mirror:
   ```bash
   python3 ~/orchestration/tools/redact-secrets.py --in-place confluence/
   git add -A && git commit -m "chore(mirror): redact secret-shaped values"
   ```
   Why: internal wiki pages hold keys and passwords in text. The hook now blocks any commit that
   carries one. Never allowlist the mirror directory; that would disable the gate where it matters.

5. **Prove the gate.**
   ```bash
   printf 'API_KEY=sk_%s_0123456789abcdef\n' live > scratch-secret.txt && git add scratch-secret.txt
   ```
   Ask Claude Code to commit. Expect BLOCKED by secrets-scan. Then
   `git rm --cached -q scratch-secret.txt && rm scratch-secret.txt`.

6. **Restart Claude Code.** Run `/memory`. Expect the kit `CLAUDE.md` and `CLAUDE.local.md` listed.

7. **Managed settings.** `ls /etc/claude-code/managed-settings.json 2>/dev/null`. If it exists,
   the organization's settings win; repeat step 5 to confirm hooks still fire.

Done when: all seven report OK. Write any friction to `~/orchestration/FOLLOWUPS.md`.
