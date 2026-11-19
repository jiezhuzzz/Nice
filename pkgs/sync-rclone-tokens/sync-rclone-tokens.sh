#!/usr/bin/env bash
# Run this BEFORE the first `home-manager switch` on a node: if the tokens are
# missing at activation, rclone-config.service fails and the
# rclone-mount:@{gdrive,box}.service units never start. Recovery after dropping
# them in:
#   systemctl --user start rclone-config.service
#   systemctl --user start 'rclone-mount:@gdrive.service' 'rclone-mount:@box.service'
set -euo pipefail

HOSTS=("$@")
[ "${#HOSTS[@]}" -eq 0 ] && HOSTS=(goku vegeta)

for host in "${HOSTS[@]}"; do
  echo "=== $host ==="
  ssh "$host" 'mkdir -p ~/.local/share/rclone'
  for remote in gdrive box; do
    src="/run/agenix/rclone-${remote}-token"
    dst=".local/share/rclone/${remote}-token"
    if [ -r "$src" ]; then
      scp -p "$src" "$host:$dst"
      # shellcheck disable=SC2029  # remote path is intentionally expanded client-side
      ssh "$host" "chmod 600 $dst"
      echo "  copied $remote token"
    elif [ -e "$src" ]; then
      echo "  WARN: $src exists but is not readable by you; skipping $remote" >&2
    else
      echo "  WARN: $src not present on this host (rebuild to materialize it?); skipping $remote" >&2
    fi
  done
done

echo
echo "Done. Now activate each node with its flake output (tokens must already be in place):"
echo "  home-manager switch --flake github:jiezhuzzz/nice#<output>"
