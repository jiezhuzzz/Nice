{
  den.aspects.desktop.niri = {
    nixos.programs.niri.enable = true;

    homeManager = {
      config,
      lib,
      pkgs,
      ...
    }: let
      inherit (config.nice) theme;
      noctalia = "${config.programs.noctalia.package}/bin/noctalia";
      colors = "${config.xdg.stateHome}/niri/colors.kdl";
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
          inherit colors handleLidClose noctalia;
          cursorTheme = theme.cursor.name;
          cursorSize = toString theme.cursor.size;
        };
        postCheck = ''
          ${lib.getExe pkgs.niri} validate --config "$target"
        '';
      };

      # niri cannot tell light from dark, so noctalia keeps the file config.kdl
      # includes on the current mode's colors.
      programs.noctalia.settings.theme.templates.user.niri = {
        input_path_modes = theme.pair (variant: "${pkgs.writeText "niri-${variant.slug}.kdl" ''
          layout {
              focus-ring {
                  active-color "${variant.palette.surface2}"
                  inactive-color "${variant.palette.surface0}"
              }
          }
        ''}");
        output_path = colors;
      };

      home.packages = with pkgs; [
        brightnessctl
        wl-clipboard
      ];
    };
  };
}
