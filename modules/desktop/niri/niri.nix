{
  den.aspects.desktop.niri = {
    nixos.programs.niri.enable = true;

    homeManager = {
      config,
      lib,
      pkgs,
      ...
    }: let
      noctalia = "${config.programs.noctalia.package}/bin/noctalia";
      handleLidClose = pkgs.writeShellScript "noctalia-handle-lid-close" ''
        set -euo pipefail

        outputs="$(${pkgs.niri}/bin/niri msg --json outputs)"
        if ${pkgs.jq}/bin/jq -e '
          [to_entries[] | select(.key != "eDP-1" and .value.logical != null)]
          | length > 0
        ' <<<"$outputs" >/dev/null; then
          exit 0
        fi

        exec ${noctalia} msg session lock-and-suspend
      '';
    in {
      # niri is enabled system-side by the nixos half above, which uses
      # the nixpkgs module (programs.niri.enable). That module offers enable,
      # package and useNautilus only — it has no config generator — so the
      # compositor config is hand-maintained KDL in ./config.kdl.
      #
      # home-manager's wayland.windowManager.niri is deliberately unused: it also
      # installs the niri package, its systemd user units and a portal, all of
      # which the NixOS side already provides. Only its build-time
      # `niri validate` check is borrowed, as the postCheck below.
      #
      # This module previously used niri-flake's `programs.niri.settings`, which
      # generated the KDL from typed Nix. Dropping that input removed four
      # transitive lock entries and a version skew: niri-flake's home-manager
      # module defaulted to niri 25.08 while the system actually runs the nixpkgs
      # niri (26.04 at the time of the change).
      #
      # replaceVarsWith fails the build if a placeholder goes stale.
      xdg.configFile."niri/config.kdl".source = pkgs.replaceVarsWith {
        src = ./config.kdl;
        replacements = {
          inherit handleLidClose noctalia;
          cursorTheme = config.nice.theme.cursor.name;
          cursorSize = toString config.nice.theme.cursor.size;
          focusActive = config.nice.theme.palette.surface2;
          focusInactive = config.nice.theme.palette.surface0;
        };
        postCheck = ''
          ${lib.getExe pkgs.niri} validate --config "$target"
        '';
      };

      home.packages = with pkgs; [
        brightnessctl # CLI backlight control; the keys go through noctalia now
        wl-clipboard # wl-copy/wl-paste; no CLI equivalent in noctalia's clipboard panel
      ];
    };
  };
}
