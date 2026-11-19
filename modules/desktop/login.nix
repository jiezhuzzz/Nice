{inputs, ...}: {
  # `follows` keeps one nixpkgs flake-wide, so upstream's binary cache can never
  # serve this build; it builds locally.
  flake-file.inputs.noctalia-greeter = {
    url = "github:noctalia-dev/noctalia-greeter";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.desktop.login.nixos = {config, ...}: {
    # The upstream module owns the greetd plumbing, so this module must NOT
    # configure `services.greetd` by hand.
    imports = [inputs.noctalia-greeter.nixosModules.default];

    services.displayManager.noctalia-greeter = {
      enable = true;

      greeter-args = "--session niri";

      # A one-time seed copied to /var/lib/noctalia-greeter/greeter.toml only if
      # absent; later edits do not propagate unless that file is removed.
      # Wallpaper and palette are omitted because noctalia's "Sync Now" owns them.
      settings = {
        cursor = {
          theme = config.nice.theme.cursor.name;
          inherit (config.nice.theme.cursor) size;
          path = "${config.nice.theme.cursor.package}/share/icons";
        };
        keyboard.layout = "us";
        # Without it the greeter auto-scales from EDID DPI (~1.68 on eDP-1),
        # while niri runs the desktop at scale 1.
        output.scale = 1;
      };
    };
  };
}
