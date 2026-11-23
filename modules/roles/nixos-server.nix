# ssh and git signing read /run/agenix rather than a forwarded agent, which does
# not survive a detached zellij/shpool.
{
  den,
  nice,
  ...
}: {
  den.aspects.nixos-server = {
    includes = with den.aspects; [
      tailscale
      mdns
    ];

    nixos = {pkgs, ...}: {
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "no";
        settings.PasswordAuthentication = false;
      };

      virtualisation.podman = {
        enable = true;
        dockerCompat = false;
        defaultNetwork.settings.dns_enabled = true;
      };

      environment.systemPackages = with pkgs; [
        skopeo
        podman-tui
      ];
    };

    provides.to-users.includes = with den.aspects; [
      homelab
      server
      ssh-identities
      git-agentless-signing
    ];

    # SAFETY: scoped to jie, so a second user gets neither jie's credentials nor
    # the root-equivalent podman group.
    provides.${nice.user.name}.user = {osConfig, ...}: {
      # SAFETY: podman socket access is root-equivalent, which `wheel` already
      # grants on this box.
      extraGroups = ["media" "podman"];
      # Only seeds the password at account creation (mutable users). Rotate with
      # `passwd`, then re-encrypt the hash into secrets/users/jie-password-hash.age.
      hashedPasswordFile = osConfig.age.secrets.jie-password-hash.path;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxEzB8rb/S0bPaTymoXEj0OFj7FXy2XTapYXLJBMBkj"
      ];
    };
  };
}
