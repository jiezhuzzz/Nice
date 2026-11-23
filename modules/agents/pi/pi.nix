{inputs, ...}: let
  # Pi has no retention setting; delete only transcripts idle for over seven days.
  sessionCleanup = pkgs:
    pkgs.writeShellScript "pi-session-cleanup" ''
      set -eu
      if [ -d "$1" ]; then
        ${pkgs.findutils}/bin/find "$1" -type f -name '*.jsonl' -mmin +10080 -delete
      fi
    '';
in {
  # Do not import upstream's homeManagerModules.default: it hardcodes
  # ~/.pi/agent/themes and rewrites settings.json, fighting the read-only store
  # symlink.
  flake-file.inputs.pi-catppuccin = {
    url = "github:otahontas/pi-coding-agent-catppuccin";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.pi.homeManager = {
    config,
    inputs',
    lib,
    pkgs,
    ...
  }: let
    inherit (config.nice) theme;
    llmAgents = inputs'.llm-agents.packages;
    piThemes = "${inputs'.pi-catppuccin.packages.default}/share/pi/themes";
    sessionDir = "${config.xdg.stateHome}/pi/sessions";
    cleanup = sessionCleanup pkgs;

    # Segment order follows ../claude-code/statusline, the Claude Code status
    # mod. pi-starship has a single palette, so the colors are roles of pi's
    # active theme (`pi:<role>`), which does follow the terminal.
    role = name: "fg:pi:${name}";
    sep = "[ │ ](${role "dim"})";
    piStarshipSettings = {
      format = "$model $thinking${sep}$directory(${sep}$git_branch)(${sep}$git_worktree)${sep}$context${sep}$cost";
      model = {
        format = "[$model]($style)";
        style = "bold ${role "border"}";
      };
      thinking = {
        format = "[$level]($style)";
        style = role "borderAccent";
      };
      directory = {
        format = "[$path]($style)";
        style = role "text";
        fish_style_pwd_dir_length = 1;
      };
      git_branch = {
        format = "[$branch]($style)";
        style = role "accent";
      };
      git_worktree = {
        format = "[$name]($style)";
        style = role "mdCode";
      };
      context = {
        format = "[$percentage]($style)";
        display = [
          {
            threshold = 0;
            style = role "success";
            hidden = false;
          }
        ];
      };
      cost = {
        symbol = "$";
        format = "[$symbol$cost]($style)";
        display = [
          {
            threshold = 0;
            style = "bold ${role "error"}";
            hidden = false;
          }
        ];
      };
    };
  in {
    programs.pi-coding-agent = {
      enable = true;
      package = llmAgents.pi;
      configDir = "${config.xdg.configHome}/pi/agent";
      settings = {
        defaultProvider = "openai";
        defaultModel = "gpt-6-astra";
        enabledModels = [
          "openai/gpt-6-astra"
          "openai-codex/gpt-6-astra"
        ];
        defaultThinkingLevel = "xhigh";
        quietStartup = true;
        hideThinkingBlock = false;
        packages = [
          # "npm:context-mode"
          "npm:pi-subagents"
          "npm:pi-web-access"
          "npm:@narumitw/pi-starship"
          "npm:pi-btw"
          "npm:pi-ask-user"

          "${inputs.ponytail}"
          "${inputs.caveman}"
        ];

        extensions = ["${./rewind-aborted-prompt.ts}"];
        skills = ["${inputs.superpowers}/skills/systematic-debugging"];
        themes = [piThemes];
        # Light first; pi switches between the two with the terminal.
        theme = "${theme.variants.light.slug}/${theme.variants.dark.slug}";
      };
    };

    # pi-starship rejects symlinks, so changes made through `/starship` last only
    # until the next activation.
    home.activation.piStarshipSettings = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${pkgs.coreutils}/bin/install -Dm600 \
        ${(pkgs.formats.toml {}).generate "pi-starship.toml" piStarshipSettings} \
        ${lib.escapeShellArg "${config.programs.pi-coding-agent.configDir}/pi-starship.toml"}
    '';

    home.sessionVariables.PI_CODING_AGENT_SESSION_DIR = sessionDir;

    launchd.agents.pi-session-cleanup = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      config = {
        ProgramArguments = ["${cleanup}" sessionDir];
        RunAtLoad = true;
        StartCalendarInterval = [
          {
            Hour = 3;
            Minute = 0;
          }
        ];
      };
    };

    systemd.user.services.pi-session-cleanup = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit.Description = "Delete Pi sessions inactive for seven days";
      Service = {
        Type = "oneshot";
        ExecStart = "${cleanup} ${lib.escapeShellArg sessionDir}";
      };
    };
    systemd.user.timers.pi-session-cleanup = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Timer = {
        OnCalendar = "*-*-* 03:00:00";
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };
  };

  perSystem = {pkgs, ...}: {
    checks.pi-session-cleanup = pkgs.runCommand "pi-session-cleanup-test" {} ''
      mkdir -p 'sessions/--project with spaces--' sessions/keep.jsonl outside
      touch -d '169 hours ago' 'sessions/--project with spaces--/expired.jsonl' \
        sessions/notes.json sessions/keep.jsonl outside/old.jsonl
      touch -d '167 hours ago' 'sessions/--project with spaces--/recent.jsonl'
      touch 'sessions/--project with spaces--/new.jsonl'
      ln -s "$PWD/outside" sessions/linked
      ln -s "$PWD/outside/old.jsonl" sessions/linked.jsonl
      touch -h -d '169 hours ago' sessions/linked.jsonl

      ${sessionCleanup pkgs} "$PWD/missing"
      ${sessionCleanup pkgs} "$PWD/sessions"

      test ! -e missing
      test ! -e 'sessions/--project with spaces--/expired.jsonl'
      test -f 'sessions/--project with spaces--/recent.jsonl'
      test -f 'sessions/--project with spaces--/new.jsonl'
      test -f sessions/notes.json
      test -f outside/old.jsonl
      test -L sessions/linked.jsonl
      test -d sessions/keep.jsonl
      touch "$out"
    '';
  };
}
