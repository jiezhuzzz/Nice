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
      # home-manager's wayland.windowManager.niri is deliberately unused: it also
      # installs the niri package, its systemd user units and a portal, all of
      # which the NixOS side already provides.
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
        brightnessctl
        wl-clipboard
      ];
    };
  };
}
