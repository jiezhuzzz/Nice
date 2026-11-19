# Miniflux — self-hosted RSS/Atom reader, postgres-backed. Tailnet-only: binds
# 127.0.0.1, no firewall port, caddy is the only way in. Login is skipped via
# the X-Auth-User header caddy sets. Private-network fetching is on so
# rsshub.nix is subscribable, at the cost of miniflux's SSRF guard.
{nice, ...}: {
  den.aspects.homelab.miniflux.nixos = {config, ...}: {
    nice.web.services.miniflux = {
      port = 8086;
      order = 90;
      # Passwordless login (AUTH_PROXY_HEADER below). No +/- prefix means *set*,
      # so a client's own X-Auth-User is replaced, not appended.
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
        FETCHER_ALLOW_PRIVATE_NETWORKS = "1";
      };
    };
  };
}
