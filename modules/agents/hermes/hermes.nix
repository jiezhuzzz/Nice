# Run `hermes auth add openai-codex` once per host: the OAuth token lives in
# ~/.hermes/auth.json, outside Nix.
{inputs, ...}: {
  # A release tag, not main: main takes a canary build every day.
  #
  # No nixpkgs follows: upstream patches the patchelf of its own pinned nixpkgs
  # (pm-packages.nix), and that patch fails to apply to ours.
  flake-file.inputs.hermes-agent = {
    url = "github:NousResearch/hermes-agent/v0.23.4";
    inputs.flake-parts.follows = "flake-parts";
    inputs.home-manager.follows = "home-manager";
  };

  den.aspects.hermes.homeManager = {inputs', ...}: {
    imports = [inputs.hermes-agent.homeManagerModules.default];

    programs.hermes-agent.enable = true;

    services.hermes-agent = {
      enable = true;
      settings.model = {
        provider = "openai-codex";
        default = "gpt-6-astra";
      };
    };

    home.packages = [inputs'.llm-agents.packages.hermes-hud];
  };
}
