#!/usr/bin/env bash
# Attach the site's floating IP to the first instance of a lease
# Usage: attach-floating-ips.sh <lease-name>
set -euo pipefail

CHI="$(cd "$(dirname "$0")" && pwd)/chi.sh"

LEASE_NAME="${1:?Usage: $0 <lease-name>}"
CHI_SITE="${CHI_SITE:-uc}"

case "$CHI_SITE" in
uc | tacc) ;;
*)
  echo "Unknown site: $CHI_SITE" >&2
  exit 1
  ;;
esac

# The uc and tacc aliases are defined in NICE's modules/ssh/ssh.nix. -T
# stops ssh -G from warning about a pseudo-terminal when stdin is not a tty.
FLOATING_IP=$(ssh -G -T "$CHI_SITE" | awk '$1 == "hostname" { print $2 }')
if [ "$FLOATING_IP" = "$CHI_SITE" ]; then
  echo "ssh alias $CHI_SITE has no HostName; switch to NICE's ssh config first" >&2
  exit 1
fi

INSTANCE="$LEASE_NAME-1"
echo "Floating IP: $FLOATING_IP (CHI@${CHI_SITE^^})"
echo "Target instance: $INSTANCE"

echo "Checking if floating IP is currently attached..."
current_server=$("$CHI" openstack floating ip show "$FLOATING_IP" -f json | jq -r '.port_id // empty')
if [ -n "$current_server" ]; then
  echo "  Detaching from current server..."
  "$CHI" openstack floating ip unset --port "$FLOATING_IP"
fi

echo "Attaching $FLOATING_IP to $INSTANCE..."
"$CHI" openstack server add floating ip "$INSTANCE" "$FLOATING_IP"

echo ""
echo "Verifying..."
"$CHI" openstack server show "$INSTANCE" -f json | jq '{name, status, addresses}'

echo ""
echo "SSH access:"
echo "  Bastion: ssh cc@$FLOATING_IP"
echo "  Other nodes: ssh -J cc@$FLOATING_IP cc@<private-ip>"
echo "Done."
