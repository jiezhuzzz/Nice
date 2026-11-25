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
    minutes = 15;
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

        uda = lib.genAttrs ["agent" "session" "repo"] (name: {
          type = "string";
          label = lib.toSentenceCase name;
        });
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
      Timer = {
        OnCalendar = "*:0/${toString minutes}";
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };

    launchd.agents.task-sync = lib.mkIf isDarwin {
      enable = true;
      config = {
        ProgramArguments = sync;
        StartInterval = minutes * 60;
        RunAtLoad = true;
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/task-sync.log";
      };
    };
  };
}
