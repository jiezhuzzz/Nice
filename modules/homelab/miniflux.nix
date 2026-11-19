{nice, ...}: {
  den.aspects.homelab.miniflux.nixos = {config, ...}: {
    nice.web.services.miniflux = {
      port = 8086;
      order = 90;
      # SAFETY: no +/- prefix means *set*, so a client's own X-Auth-User is
      # replaced, not appended.
      proxyDirectives = "header_up X-Auth-User ${nice.user.name}";
      tile = {
        title = "Miniflux";
        icon = "di:miniflux";
      };
    };

    services.miniflux = {
      enable = true;
      adminCredentialsFile = config.age.secrets.miniflux-admin-credentials.path;

      config = {
        LISTEN_ADDR = "127.0.0.1:${toString config.nice.web.services.miniflux.port}";
        BASE_URL = config.nice.web.services.miniflux.url;
        AUTH_PROXY_HEADER = "X-Auth-User";
        TRUSTED_REVERSE_PROXY_NETWORKS = "127.0.0.1/32";
        # Lets rsshub.nix be subscribed to, at the cost of miniflux's SSRF guard.
        FETCHER_ALLOW_PRIVATE_NETWORKS = "1";
      };
    };
  };
}
