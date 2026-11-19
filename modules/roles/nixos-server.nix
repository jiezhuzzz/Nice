# Its users' ssh and git signing read the files under /run/agenix rather than
# a forwarded agent, so github, the forge, the lab and Chameleon all keep
# authenticating from a detached tmux/shpool, where no agent survives.
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
      # Headless access — key-only, no password over SSH (jie has an authorized key
      # below). The console password still works for physical recovery.
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "no";
        settings.PasswordAuthentication = false;
      };

      # Podman — rootless-capable container runtime. Keep the Docker CLI shim
      # disabled so callers explicitly select Podman. DNS in the default network
      # lets containers resolve each other by name (needed by most compose stacks).
      virtualisation.podman = {
        enable = true;
        dockerCompat = false;
        defaultNetwork.settings.dns_enabled = true;
      };

      environment.systemPackages = with pkgs; [
        skopeo # inspect/copy container images (e.g. resolve pinned digests for podman)
        podman-tui # TUI over the podman socket (connection in modules/homelab/podman-tui.nix)
      ];
    };

    provides.to-users.includes = with den.aspects; [
      homelab
      server
      ssh-identities
      git-agentless-signing
    ];

    # jie's own account on a server, so a second user gets neither jie's
    # credentials nor the root-equivalent podman group.
    provides.${nice.user.name}.user = {osConfig, ...}: {
      # `podman` is the SocketGroup on /run/podman/podman.sock, so it is what
      # lets podman-tui reach the rootful containers above without sudo. Socket
      # access is root-equivalent, which `wheel` already grants on this box.
      extraGroups = ["media" "podman"];
      # Seeds the password only when the account is created: with mutable users,
      # activation leaves an existing one alone. Rotate it with `passwd`, then
      # re-encrypt the new hash into secrets/users/jie-password-hash.age.
      hashedPasswordFile = osConfig.age.secrets.jie-password-hash.path;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxEzB8rb/S0bPaTymoXEj0OFj7FXy2XTapYXLJBMBkj"
      ];
    };
  };
}
