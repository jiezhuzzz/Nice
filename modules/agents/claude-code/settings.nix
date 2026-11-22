{
  flake-file.inputs.llm-agents = {
    url = "github:numtide/llm-agents.nix";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-parts.follows = "flake-parts";
    inputs.treefmt-nix.follows = "treefmt-nix";
  };

  den.aspects.claude-code.settings.homeManager = {
    config,
    inputs',
    ...
  }: let
    llmAgents = inputs'.llm-agents.packages;
  in {
    programs.claude-code = {
      enable = true;
      package = llmAgents.claude-code;
      configDir = "${config.xdg.configHome}/claude";
      settings = {
        model = "opus[1m]";
        # Only applies while auto-compact is on.
        autoCompactWindow = 400000;
        autoMemoryEnabled = false;
        # Unset is not off: Claude Code falls back to the org policy default and a
        # server-side rollout gate.
        remoteControlAtStartup = false;
        skillOverrides = {
          claude-api = "user-invocable-only";
        };
        permissions = {
          defaultMode = "auto";
          allow = map (cmd: "Bash(gh ${cmd} *)") [
            "api"
            "repo view"
            "repo list"
            "pr view"
            "pr list"
            "pr diff"
            "pr checks"
            "pr status"
            "issue view"
            "issue list"
            "issue status"
            "run view"
            "run list"
            "workflow view"
            "workflow list"
            "release view"
            "release list"
            "label list"
            "search"
            "status"
          ];
          # `gh api` turns into a write once it is given a method, fields or an
          # input body; denying those keeps the allow above read-only. No space
          # after `api`, so a flag placed first (`gh api -X POST …`) matches too.
          deny = map (flag: "Bash(gh api* ${flag}*)") [
            "-X"
            "--method"
            "-f"
            "-F"
            "--field"
            "--raw-field"
            "--input"
          ];
        };
        skipDangerousModePermissionPrompt = true;
        # A setting rather than CLAUDE_CODE_EFFORT_LEVEL: the env var outranks
        # /effort, so it would block session-only changes (`s` in the slider).
        # Per-model because Claude Code (2.1.303) honours a top-level
        # effortLevel in user settings only for a legacy model list ending at
        # opus-5/fable-5-1; newer models read modelSettings.<model> alone. Keys
        # are alias-resolved before matching, so `opus` follows each new Opus.
        modelSettings.opus.effortLevel = "xhigh";
        env = {
          CLAUDE_CODE_PLUGIN_CACHE_DIR = "${config.xdg.cacheHome}/claude/plugins";
          CLAUDE_CODE_DEBUG_LOGS_DIR = "${config.xdg.stateHome}/claude/logs";
          CLAUDE_CODE_TMPDIR = "/tmp/claude-code-${config.home.username}";
        };
        outputStyle = "Concise";
        theme = "auto";
        tui = "fullscreen";
        attribution = {
          commit = "";
          pr = "";
        };
        disableAgentView = true;
        cleanupPeriodDays = 7;
      };
    };

    # The status is a mod, not the `statusLine` setting: a `statusLine` command
    # gets a row of its own above the permission-mode row, and Claude Code
    # (2.1.327) has no setting that merges the two.
    #
    # Not `programs.claude-code.plugins`: that wraps a plugin in a directory of
    # symlinks, and Claude Code refuses a hooks module that resolves to outside
    # its plugin's directory.
    home.file."${config.programs.claude-code.configDir}/skills/statusline".source = ./statusline;
  };
}
