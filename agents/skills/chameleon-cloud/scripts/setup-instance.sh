#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <ip> [<ip2> ...]" >&2
  echo "Set SSH_JUMP=cc@<bastion-ip> for nodes behind a bastion" >&2
  exit 1
fi

STEPS="${STEPS:-terminfo apt userns linger nix}"
SSH_KEY="${SSH_KEY:-/run/agenix/chameleon-ssh-key}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -i "$SSH_KEY")
if [ -n "${SSH_JUMP:-}" ]; then
  # OpenSSH does not pass -i through to a -J hop, so a non-default SSH_KEY
  # would not reach the bastion.
  SSH_OPTS+=(-o "ProxyCommand=ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new -W %h:%p $SSH_JUMP")
fi

step_terminfo() {
  infocmp -x xterm-ghostty | ssh "${SSH_OPTS[@]}" cc@"$1" -- tic -x -
}

step_apt() {
  ssh "${SSH_OPTS[@]}" cc@"$1" 'sudo apt update && sudo apt upgrade -y && sudo apt install -y uidmap podman slirp4netns'
}

step_userns() {
  # Rootless podman needs unprivileged user namespaces.
  ssh "${SSH_OPTS[@]}" cc@"$1" 'sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0 && echo "kernel.apparmor_restrict_unprivileged_userns=0" | sudo tee /etc/sysctl.d/99-userns.conf'
}

step_linger() {
  ssh "${SSH_OPTS[@]}" cc@"$1" 'sudo loginctl enable-linger cc'
}

step_nix() {
  ssh "${SSH_OPTS[@]}" cc@"$1" 'curl --proto "=https" --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm'
}

for step in $STEPS; do
  declare -F "step_$step" >/dev/null || {
    echo "Unknown step: $step" >&2
    exit 1
  }
done

for ip in "$@"; do
  echo "=== Setting up $ip ($STEPS) ==="
  ssh-keygen -R "$ip" 2>/dev/null || true
  for step in $STEPS; do
    "step_$step" "$ip"
  done
  echo "=== $ip setup complete ==="
done
