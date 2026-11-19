# SAFETY: openFirewall is any-source; the box is NAT'd (v4) and ULA-only (v6).
{
  den.aspects.homelab.searxng.nixos = {config, ...}: {
    nice.web.services.searx = {
      port = 8085;
      lan = true;
      order = 50;
      tile = {
        title = "SearXNG";
        icon = "di:searxng";
      };
    };

    services.searx = {
      enable = true;
      openFirewall = true;

      environmentFile = config.age.secrets.searxng-secret-key.path;

      settings = {
        server = {
          bind_address = "0.0.0.0";
          port = config.nice.web.services.searx.port;
          secret_key = "$SEARX_SECRET_KEY";
          # SAFETY: safe only while reachable from LAN/tailnet alone; otherwise
          # enable it with services.searx.redisCreateLocally.
          limiter = false;
        };
        search = {
          formats = ["html" "json"]; # pi's searxng provider gets 403 without "json"
          safe_search = 0;
          default_lang = "all";
        };
        ui = {
          static_use_hash = true;
          default_locale = "en";
        };
        general.instance_name = "Homelab Search";
      };
    };
  };
}
