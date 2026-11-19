# Shiori — self-hosted bookmarks manager (save, archive, tag, full-text
# search), replacing karakeep. A single Go binary over SQLite in
# /var/lib/shiori: no Node, no Meilisearch, no build step, and none of the
# better-sqlite3 startup aborts that kept karakeep down.
#
# Tailnet-only like miniflux/memos/vault: binds 127.0.0.1 and opens no
# firewall port, so the caddy vhost is the only way in.
#
# Login is skipped via the Remote-User header caddy sets, the same trick
# miniflux uses. Two upstream details decide the settings below:
#
#   - SSO_PROXY_AUTH_TRUSTED defaults to the RFC1918 ranges only, which do NOT
#     cover the loopback address caddy connects from — left alone, every
#     proxied request is rejected as "remoteAddr is not a trusted ip".
#   - the middleware resolves the header with GetAccountByUsername and never
#     creates anything. Shiori seeds a single `shiori` account (password
#     `gopher`) when the database has none, so `jie` must be created once by
#     hand: log in as shiori/gopher, add the account, then change or delete the
#     seeded one. Normal login keeps working next to the header.
#
# SHIORI_HTTP_SECRET_KEY is deliberately left unset. Shiori then picks a random
# key per start and warns that sessions do not survive a restart — which costs
# nothing here, because the header re-authenticates every request anyway.
{nice, ...}: {
  den.aspects.homelab.shiori.nixos = {config, ...}: {
    nice.web.services.shiori = {
      port = 8084;
      order = 80;
      # Passwordless login (SSO proxy auth below). No +/- prefix means *set*, so
      # a client's own Remote-User is replaced, not appended.
      proxyDirectives = "header_up Remote-User ${nice.user.name}";
      tile = {
        title = "Shiori";
        icon = "di:shiori";
      };
    };

    services.shiori = {
      enable = true;
      address = "127.0.0.1";
      port = config.nice.web.services.shiori.port;
    };

    systemd.services.shiori.environment = {
      SHIORI_SSO_PROXY_AUTH_ENABLED = "true";
      SHIORI_SSO_PROXY_AUTH_HEADER_NAME = "Remote-User";
      SHIORI_SSO_PROXY_AUTH_TRUSTED = "127.0.0.1/32";
    };
  };
}
