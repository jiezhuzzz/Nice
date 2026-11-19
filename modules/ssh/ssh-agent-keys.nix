# On Linux the agent is gcr-ssh-agent, which nothing in this flake enables
# directly: its default follows services.gnome.gnome-keyring.enable, which
# nixpkgs' programs.niri turns on.
{
  den.aspects.ssh-agent-keys.homeManager = {
    lib,
    osConfig,
    pkgs,
    ...
  }: let
    keys = map (name: osConfig.age.secrets.${name}.path) [
      "github-ssh-key"
      "git-signing-key"
      "chameleon-ssh-key"
      "lab-ssh-key"
      "home-ssh-key"
    ];
  in {
    launchd.agents.ssh-add-keys = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      config = {
        Label = "com.user.ssh-add-keys";
        ProgramArguments = ["/usr/bin/ssh-add"] ++ keys;
        RunAtLoad = true;
      };
    };

    systemd.user.services.ssh-add-keys = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit.Description = "Load SSH keys into agent";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.openssh}/bin/ssh-add ${lib.concatStringsSep " " keys}";
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
