{
  den.aspects.homelab.litellm.nixos = {config, ...}: {
    services.litellm = {
      enable = true;
      host = "127.0.0.1";
      port = 4000;
      environmentFile = config.age.secrets.litellm-provider-keys.path;
      # LiteLLM >= 1.108 refuses to start without a master key; keyless is safe
      # because it only listens on localhost.
      settings.general_settings.dangerously_permit_weak_or_unset_master_key = true;
      settings.model_list = [
        {
          model_name = "Claude Opus 4.8 (high)";
          litellm_params = {
            model = "anthropic/claude-opus-4-8";
            api_key = "os.environ/ANTHROPIC_API_KEY";
            reasoning_effort = "high";
          };
        }
        {
          model_name = "OpenAI GPT-5.5 (high)";
          litellm_params = {
            model = "openai/gpt-5.5";
            api_key = "os.environ/OPENAI_API_KEY";
            reasoning_effort = "high";
          };
        }
        {
          # No reasoning_effort: Haiku doesn't accept it.
          model_name = "Claude Haiku 4.5";
          litellm_params = {
            model = "anthropic/claude-haiku-4-5";
            api_key = "os.environ/ANTHROPIC_API_KEY";
          };
        }
        {
          model_name = "text-embedding-3-small";
          litellm_params = {
            model = "openai/text-embedding-3-small";
            api_key = "os.environ/OPENAI_API_KEY";
          };
        }
      ];
    };
  };
}
