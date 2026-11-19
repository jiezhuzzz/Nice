# Enrollment is deliberately imperative, once per machine: `sudo tailscale up`
# and follow the login URL. For servers (nixmachine), afterwards disable key
# expiry in the admin console so the node never silently drops off.
{
  den.aspects.tailscale.nixos = {
    services.tailscale = {
      enable = true;
      openFirewall = true;
    };
    # SAFETY: the tailnet contains only jie's logged-in devices.
    networking.firewall.trustedInterfaces = ["tailscale0"];
  };
}
