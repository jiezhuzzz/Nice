{
  den.aspects.zellij.homeManager = {
    config,
    pkgs,
    lib,
    ...
  }: let
    palette = config.nice.theme.palette;

    nicebar = {
      _props.location = "file:${nicebarPath}";
      stats = lib.getExe pkgs.nicebar-stats;
      inherit (palette) text;
      muted_text = palette.subtext0;
      accent_text = palette.crust;
      session_bg = palette.surface1;
      tab_bg = palette.surface0;
      tab_active_bg = palette.mauve;
      stats_bg = palette.surface0;
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
  in {
    xdg.configFile."zellij/plugins/nicebar.wasm".source = pkgs.zellij-nicebar;

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
        show_startup_tips = false;
        show_release_notes = false;
        default_layout = "nice";
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
