{nice, ...}: {
  den.aspects.taskwarrior.homeManager = {
    config,
    lib,
    osConfig,
    pkgs,
    ...
  }: let
    cfg = config.programs.taskwarrior;
    sync = [(lib.getExe cfg.package) "sync"];
    inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
  in {
    programs.taskwarrior = {
      enable = true;
      package = pkgs.taskwarrior3;

      config = {
        # Reports otherwise end with a "run 'task news'" nag after every
        # upgrade, which lands in agents' tool output.
        news.version = cfg.package.version;

        sync.server = {
          url = "https://${nice.facts.tasks.host}";
          client_id = nice.facts.tasks.clientId;
        };

        uda = {
          agent = {
            type = "string";
            label = "Agent";
          };
          session = {
            type = "string";
            label = "Session";
          };
          repo = {
            type = "string";
            label = "Repo";
          };
        };
      };

      extraConfig = "include ${osConfig.age.secrets.taskwarrior-sync.path}";
    };

    home.packages = [pkgs.taskwarrior-tui];

    systemd.user.services.task-sync = lib.mkIf isLinux {
      Unit.Description = "Sync Taskwarrior with the TaskChampion server";
      Service = {
        Type = "oneshot";
        ExecStart = lib.escapeShellArgs sync;
      };
    };

    systemd.user.timers.task-sync = lib.mkIf isLinux {
      Unit.Description = "Sync Taskwarrior every 15 minutes";
      Timer = {
        OnCalendar = "*:0/15";
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };

    launchd.agents.task-sync = lib.mkIf isDarwin {
      enable = true;
      config = {
        Label = "com.user.task-sync";
        ProgramArguments = sync;
        StartInterval = 900;
        RunAtLoad = true;
      };
    };
  };
}
