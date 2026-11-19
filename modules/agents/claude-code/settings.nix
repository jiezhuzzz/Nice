# Claude Code itself: package, config location, and every settings key not
# owned by a sibling (hooks/ owns settings.hooks and settings.permissions.deny,
# statusline.nix owns settings.statusLine). A scalar set differently in two
# files is an eval error, but lists from two files concatenate silently.
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
    # claude-code from llm-agents.nix (upstream tracks it faster than nixpkgs).
    llmAgents = inputs'.llm-agents.packages;
  in {
    programs.claude-code = {
      enable = true;
      package = llmAgents.claude-code;
      configDir = "${config.xdg.configHome}/claude";
      settings = {
        model = "opus[1m]";
        # Compact against a 400k window rather than the model's real 1M — frequent
        # cheap compactions instead of one enormous one. Only live while
        # auto-compact is on; disabling that reverts to the full model window.
        autoCompactWindow = 400000;
        # Disable auto memory: stop Claude from writing/updating its own notes
        # under ~/.config/claude/projects/<project>/memory/. CLAUDE.md and the
        # `context` in context.nix still apply (those are user-authored, not auto
        # memory).
        autoMemoryEnabled = false;
        # Remote Control off unless asked for per session (/remote-control). Left
        # unset it is not simply off: the resolver falls back to the org policy
        # default and a server-side rollout gate, so an explicit false is the
        # only way to keep the bridge from starting on its own.
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
