# SAFETY: the web UI has no authentication and its mutating endpoints answer
# anyone who reaches them, so the tailnet is the entire access control: never
# give this a LAN port or a non-loopback bind.
#
# GROBID (`grobid_url`) is deliberately off: it would need its own ~1.3GB OCI
# container for a single metadata-fallback call.
#
# Each feature is gated on the presence of its config section, so the empty
# attrsets below are meaningful: `summary = {}` renders `[ai.summary]`.
{inputs, ...}: {
  flake-file.inputs.xuewen = {
    url = "github:r3clab/Xuewen";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.treefmt-nix.follows = "treefmt-nix";
  };

  den.aspects.homelab.xuewen.nixos = {config, ...}: {
    imports = [inputs.xuewen.nixosModules.default];

    nice.web.services.xuewen = {
      port = 8087;
      order = 110;
      # No icon library carries this project.
      tile = {
        title = "Xuewen";
        icon = "https://raw.githubusercontent.com/r3clab/Xuewen/main/assets/logo.svg";
      };
    };

    services.xuewen = {
      enable = true;
      port = config.nice.web.services.xuewen.port;

      settings = {
        # Crossref's polite pool keys on this address in the User-Agent.
        contact_email = "jiezhu@uchicago.edu";

        # The rotating session cookie deliberately does not live here: set it in
        # the web UI or with `xuewen proxy-cookie --set '<cookie>'`.
        proxy.login_url = "https://proxy.uchicago.edu/login?url=";

        # Scored against the library's embeddings, so this needs [ai.embedding].
        daily.categories = [
          "cs.CR"
          "cs.SE"
          "cs.LG"
          "cs.CL"
          "cs.AI"
          "cs.OS"
          "cs.DC"
          "cs.PL"
        ];

        translate = {
          target_lang = "zh";
          # Free-tier keys end in ":fx"; a paid key needs "pro" or DeepL answers
          # 403.
          deepl = {
            api_key_env = "DEEPL_API_KEY";
            plan = "free";
          };
        };

        ai = {
          # A placeholder, not a secret: LiteLLM has no master key, but the client
          # requires a non-empty string.
          base_url = "http://${config.services.litellm.host}:${toString config.services.litellm.port}/v1";
          api_key = "litellm-local";
          # Must match a model_name in litellm.nix.
          model = "Claude Haiku 4.5";
          summary = {};
          citations = {};
          daily = {};
          translate = {};

          # dims must match what the API returns or the embedder aborts. Changing
          # either means `xuewen index rebuild --vectors-only`.
          embedding = {
            model = "text-embedding-3-small";
            dims = 1536;
          };

          agent = {
            claude_code = {};
            codex = {};
          };
        };
      };

      # Same encrypted file LiteLLM reads, under its own name in
      # modules/secrets.nix so it outlives LiteLLM's entry.
      environmentFile = config.age.secrets.xuewen-provider-keys.path;
    };
  };
}
