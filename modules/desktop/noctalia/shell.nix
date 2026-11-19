{
  den.aspects.desktop.noctalia.shell.homeManager = {pkgs, ...}: {
    programs.noctalia = {
      enable = true;
      systemd.enable = true;

      # The settings GUI writes its overrides to a separate settings.toml, so a
      # read-only store symlink for this base config is fine.
      settings = {
        bar.main = {
          scale = 1.5;
          smart_auto_hide = true;
          reserve_space = false;
        };

        shell = {
          # Without it, apps launched from noctalia are children of the service
          # and get killed whenever the unit restarts.
          launch_apps_as_systemd_services = true;

          # Nothing else on this machine provides a polkit agent; without one
          # every GUI privilege prompt fails instead of asking.
          polkit_agent = true;

          # SAFETY: plain suspend is omitted so every suspend goes through the
          # lock-aware guard in sleep-guard.nix.
          session = {
            actions = [
              {
                action = "lock";
                shortcut = "1";
              }
              {
                action = "logout";
                shortcut = "2";
              }
              {
                action = "lock_and_suspend";
                shortcut = "3";
              }
              {
                action = "reboot";
                shortcut = "4";
              }
              {
                action = "shutdown";
                shortcut = "5";
                variant = "destructive";
              }
            ];
          };
        };

        lockscreen.enabled = true;

        idle = {
          pre_action_fade_seconds = 2.0;
          behavior = {
            lock = {
              enabled = true;
              timeout = 300;
              action = "lock";
            };
            "screen-off" = {
              enabled = true;
              timeout = 330;
              action = "screen_off";
            };
            "lock-and-suspend" = {
              enabled = true;
              timeout = 600;
              action = "lock_and_suspend";
            };
          };
        };

        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Catppuccin";

          # Templates rewrite other apps' home-manager-owned config files in
          # place, failing the next activation with "would be clobbered".
          # Enabling one in the settings GUI overrides this.
          templates.builtin_ids = [];
        };
      };
    };

    home.packages = [pkgs.papirus-icon-theme];
  };
}
