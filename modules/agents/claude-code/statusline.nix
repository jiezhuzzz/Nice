{
  den.aspects.claude-code.statusline.homeManager = {
    inputs',
    pkgs,
    ...
  }: let
    ccstatusline = inputs'.llm-agents.packages.ccstatusline;

    nord = {
      polarNight3 = "hex:4c566a";
      snowStorm0 = "hex:d8dee9";
      frost0 = "hex:8fbcbb";
      frost1 = "hex:88c0d0";
      frost2 = "hex:81a1c1";
      frost3 = "hex:5e81ac";
      red = "hex:bf616a";
      orange = "hex:d08770";
      yellow = "hex:ebcb8b";
      green = "hex:a3be8c";
      purple = "hex:b48ead";
    };

    seg = id: type: color: extra: {inherit id type color;} // extra;

    sep = id: {
      inherit id;
      type = "separator";
      character = "│";
      color = nord.polarNight3;
    };

    # One config per login: ccstatusline fills a bucket missing from the payload
    # from the usage API, which reports the other plan's window at 0%.
    usage = {
      session = seg "session" "session-usage" nord.orange {metadata.label = "5h: ";};
      weekly = seg "weekly" "weekly-usage" nord.orange {metadata.label = "7d: ";};
    };

    mkSettings = usageWidget: {
      # Must equal ccstatusline's CURRENT_VERSION (2.2.29: 4). Anything lower is
      # migrated and written back — into the read-only store here, so the write
      # fails and every render falls back to defaults with "⚠ invalid config".
      version = 4;
      colorLevel = 3;
      defaultPadding = " ";
      defaultPaddingSide = "both";
      numberFormat.percent.style = "whole";
      # Must exceed statusLine.refreshInterval, or every timed re-render would
      # re-fork git.
      gitCacheTtlSeconds = 30;
      lines = [
        [
          (seg "model" "model" nord.frost1 {
            bold = true;
            rawValue = true;
            merge = "no-padding";
          })
          {
            id = "model-gap";
            type = "custom-text";
            customText = " ";
            merge = "no-padding";
          }
          (seg "effort" "thinking-effort" nord.frost2 {rawValue = true;})
          (sep "sep-cwd")
          (seg "cwd" "current-working-dir" nord.snowStorm0 {
            rawValue = true;
            metadata.fishStyle = "true";
          })
          (sep "sep-branch")
          (seg "branch" "git-branch" nord.purple {
            rawValue = true;
            metadata.hide = "no-git";
          })
          (sep "sep-worktree")
          (seg "worktree" "worktree-name" nord.frost0 {rawValue = true;})
          (sep "sep-ctx")
          (seg "ctx" "context-percentage" nord.green {metadata.label = "Ctx: ";})
          (sep "sep-usage")
          usageWidget
          (sep "sep-cost")
          (seg "cost" "session-cost" nord.red {
            bold = true;
            rawValue = true;
          })
          (sep "sep-clock")
          (seg "clock" "session-clock" nord.frost3 {rawValue = true;})
        ]
      ];
    };

    toJSON = name: (pkgs.formats.json {}).generate name;
    enterpriseSettings = toJSON "ccstatusline-enterprise.json" (mkSettings usage.session);
    personalSettings = toJSON "ccstatusline-settings.json" (mkSettings usage.weekly);

    # `/login` swaps accounts inside the one config dir, so the account is only
    # knowable at render time, from the oauthAccount that .claude.json records.
    statusline = pkgs.writeShellScript "ccstatusline-by-account" ''
      if ${pkgs.gnugrep}/bin/grep -qE '"organizationType": *"claude_enterprise"' "''${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json" 2>/dev/null; then
        exec ${ccstatusline}/bin/ccstatusline --config ${enterpriseSettings}
      fi
      exec ${ccstatusline}/bin/ccstatusline --config ${personalSettings}
    '';
  in {
    home.packages = [ccstatusline];

    xdg.configFile."ccstatusline/settings.json".source = personalSettings;

    programs.claude-code.settings.statusLine = {
      type = "command";
      command = "${statusline}";
      padding = 0;
      refreshInterval = 10;
    };
  };
}
