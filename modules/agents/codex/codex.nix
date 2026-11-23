{nice, ...}: {
  den.aspects.codex.homeManager = {
    config,
    inputs',
    ...
  }: let
    llmAgents = inputs'.llm-agents.packages;
  in {
    programs.codex = {
      enable = true;
      # HACK: upstream trusts only the literal path in `[projects."<dir>"]`, so
      # pre-trusting $HOME would not cover its subdirectories. See
      # https://github.com/openai/codex/issues/14601. Written against codex
      # 0.164.0.
      package = llmAgents.codex.overrideAttrs (old: {
        patches = (old.patches or []) ++ [./recursive-project-trust.patch];
      });
      settings = {
        # approvals_reviewer only takes effect with approval_policy = "on-request".
        approval_policy = "on-request";
        approvals_reviewer = "auto_review";
        sandbox_mode = "workspace-write";

        # config.toml is a read-only store symlink, so Codex persisting trust at
        # runtime fails (the TUI hides the cause: openai/codex#25008).
        projects.${config.home.homeDirectory}.trust_level = "trusted";

        mcp_servers.notion.url = "https://mcp.notion.com/mcp";

        personality = "pragmatic";
        features.memories = false;
        tui.notifications = true;
        tui.status_line = [
          "model-with-reasoning"
          "context-remaining"
          "five-hour-limit"
          "weekly-limit"
          "current-dir"
        ];
        model_reasoning_effort = "high";
      };
      context = nice.agents.context;
      rules.deny-python = ''
        prefix_rule(pattern = ["python"], decision = "forbidden", justification = "Use uv run instead of python directly")
        prefix_rule(pattern = ["python3"], decision = "forbidden", justification = "Use uv run instead of python3 directly")
        prefix_rule(pattern = ["pip"], decision = "forbidden", justification = "Use uv for dependency management")
        prefix_rule(pattern = ["pip3"], decision = "forbidden", justification = "Use uv for dependency management")
        prefix_rule(pattern = ["uv", "pip"], decision = "forbidden", justification = "Use uv add or inline script metadata instead")
      '';
      # A custom `model_providers` entry because there is no `openai_base_url`
      # key.
      profiles.api = {
        model_provider = "openai-us";
        model_providers.openai-us = {
          name = "OpenAI (US API)";
          base_url = "https://us.api.openai.com/v1";
          env_key = "OPENAI_API_KEY";
          wire_api = "responses";
        };
      };
    };
  };
}
