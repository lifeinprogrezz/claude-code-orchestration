#!/usr/bin/env bash
# harden-vps.sh — baseline security hardening for the Plane-2 VPS, to run BEFORE
# the box holds any API key or push credential (spec §6: mandatory).
#
# Run ON the VPS, as a sudo-capable user, AFTER you have:
#   1) added your SSH public key to ~/.ssh/authorized_keys, and
#   2) confirmed key-based login works in a SEPARATE terminal (so you can't lock out).
#
# Usage:
#   ./harden-vps.sh          # safe baseline: ufw + fail2ban + automatic security updates
#   ./harden-vps.sh --ssh    # ALSO disable SSH password/root login (key-only) — guarded
#
# The --ssh step refuses to run unless ~/.ssh/authorized_keys is non-empty, tests the
# sshd config before reloading, and keeps a backup — so a mistake can't strand you.
set -euo pipefail
DO_SSH=0; [ "${1:-}" = "--ssh" ] && DO_SSH=1
say(){ echo "==> $*"; }
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

say "Packages: ufw, fail2ban, unattended-upgrades"
$SUDO apt-get update -qq
$SUDO apt-get install -y ufw fail2ban unattended-upgrades

say "Firewall: default-deny inbound, allow SSH + all outbound"
$SUDO ufw default deny incoming
$SUDO ufw default allow outgoing
$SUDO ufw allow OpenSSH
# Once Tailscale/WireGuard is up and confirmed, restrict SSH to the VPN interface and
# drop the public rule:  sudo ufw delete allow OpenSSH  (keep public SSH until then).
$SUDO ufw --force enable
$SUDO ufw status verbose

say "fail2ban: enable the sshd jail (bans brute-forcers)"
$SUDO systemctl enable --now fail2ban

say "Automatic security updates (no auto-reboot)"
echo 'Unattended-Upgrade::Automatic-Reboot "false";' | $SUDO tee /etc/apt/apt.conf.d/51unattended-reboot >/dev/null
$SUDO dpkg-reconfigure -f noninteractive unattended-upgrades || true

if [ "$DO_SSH" -eq 1 ]; then
  if [ ! -s "$HOME/.ssh/authorized_keys" ]; then
    echo "REFUSING --ssh: $HOME/.ssh/authorized_keys is empty."
    echo "Add your public key and verify key login in another terminal first, then re-run."
    exit 2
  fi
  say "Hardening sshd → key-only (backup: /etc/ssh/sshd_config.bak)"
  $SUDO cp -n /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
  $SUDO sed -i \
    -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
    -e 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' \
    -e 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' \
    -e 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' \
    /etc/ssh/sshd_config
  if $SUDO sshd -t; then
    $SUDO systemctl reload ssh 2>/dev/null || $SUDO systemctl reload sshd
    say "sshd hardened (password + root login OFF). KEEP THIS SESSION OPEN and confirm a NEW key login works before closing it."
  else
    echo "sshd config test FAILED — restoring backup, no change applied."
    $SUDO cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
    exit 3
  fi
fi

say "Baseline done."
echo "Recommended next: Tailscale (curl -fsSL https://tailscale.com/install.sh | sh; sudo tailscale up),"
echo "then restrict SSH to the tailnet and drop the public OpenSSH rule."
