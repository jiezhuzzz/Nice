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
        permissions.defaultMode = "auto";
        skipDangerousModePermissionPrompt = true;
        # A setting rather than CLAUDE_CODE_EFFORT_LEVEL: the env var outranks
        # /effort, so it would block session-only changes (`s` in the slider).
        # Per-model because Claude Code (2.1.303) honours a top-level
        # effortLevel in user settings only for a legacy model list ending at
        # opus-5/fable-5-1; newer models read modelSettings.<model> alone. Keys
        # are alias-resolved before matching, so `opus` follows each new Opus.
        modelSettings.opus.effortLevel = "high";
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
  };
}
