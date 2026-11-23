{
  # Zellij tells a nested session only its hosts' session names, so naming each
  # session after its machine is what lets nicebar show `nixmini ▸ nixmachine`.
  den.aspects.zellij.includes = [
    ({host, ...}: {homeManager.programs.zellij.settings.session_name = host.hostName;})
    ({home, ...}: {homeManager.programs.zellij.settings.session_name = home.name;})
  ];

  den.aspects.zellij.homeManager = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit (config.nice.theme) variants;

    roles = palette: {
      inherit (palette) text;
      muted_text = palette.subtext0;
      faint_text = palette.overlay1;
      ghost_text = palette.surface2;
      accent = palette.mauve;
      pill_bg = palette.crust;
      warn = palette.yellow;
      crit = palette.red;
      mode = palette.blue;
      mode_locked = palette.red;
      mode_pane = palette.green;
      mode_tab = palette.teal;
      mode_resize = palette.peach;
      mode_move = palette.yellow;
      mode_scroll = palette.sky;
      mode_search = palette.sky;
      mode_rename = palette.pink;
      mode_session = palette.flamingo;
    };

    nicebar =
      {
        _props.location = "file:${nicebarPath}";
        stats = lib.getExe pkgs.nicebar-stats;
      }
      // lib.concatMapAttrs (appearance: variant: lib.mapAttrs' (role: lib.nameValuePair "${appearance}_${role}") (roles variant.palette)) variants;

    # Zellij keys its permission cache by plugin path and shows the grant
    # prompt inside the plugin's own pane, which a one-row bar cannot fit.
    nicebarPath = "${config.xdg.configHome}/zellij/plugins/nicebar.wasm";
    permissionCache =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "${config.home.homeDirectory}/Library/Caches/org.Zellij-Contributors.Zellij/permissions.kdl"
      else "${config.xdg.cacheHome}/zellij/permissions.kdl";
    nicebarPermissions = ''
      ${builtins.toJSON nicebarPath} {
          ReadApplicationState
          ChangeApplicationState
          RunCommands
      }
    '';

    zellij = lib.getExe config.programs.zellij.package;
  in {
    xdg.configFile."zellij/plugins/nicebar.wasm".source = pkgs.zellij-nicebar;

    # Zed's remote terminal is an ssh login shell too, told apart only by the
    # ZED_TERM it exports (zed crates/terminal/src/terminal.rs).
    programs.bash.initExtra = lib.mkBefore ''
      if shopt -q login_shell && [[ -n $SSH_TTY && -z $ZELLIJ && -z $ZED_TERM ]]; then
        exec ${zellij}
      fi
    '';
    programs.fish.interactiveShellInit = lib.mkBefore ''
      if status is-login; and set -q SSH_TTY; and not set -q ZELLIJ; and not set -q ZED_TERM
          exec ${zellij}
      end
    '';

    programs.zellij = {
      enable = true;
      layouts.nice.layout._children = [
        {
          default_tab_template._children = [
            {
              pane = {
                _props = {
                  size = 1;
                  borderless = true;
                };
                _children = [{plugin._props.location = "tab-bar";}];
              };
            }
            {children = [];}
          ];
        }
      ];
      settings = {
        theme_light = variants.light.slug;
        theme_dark = variants.dark.slug;
        show_startup_tips = false;
        show_release_notes = false;
        default_layout = "nice";
        attach_to_session = true;
        # Overrides zellij's built-in alias, so its own layouts get nicebar too.
        plugins.tab-bar = nicebar;
        keybinds = {
          unbind = ["Ctrl b"];
        };
      };
    };

    home.activation.nicebarPermissions = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if ! grep -qsF ${lib.escapeShellArg (builtins.toJSON nicebarPath)} ${lib.escapeShellArg permissionCache}; then
        run mkdir -p ${lib.escapeShellArg (builtins.dirOf permissionCache)}
        printf '\n%s' ${lib.escapeShellArg nicebarPermissions} | run tee -a ${lib.escapeShellArg permissionCache} >/dev/null
      fi
    '';
  };
}
