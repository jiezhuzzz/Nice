# Proxy auth never creates accounts and Shiori seeds only `shiori` (password
# `gopher`), so create `jie` once by hand: log in as shiori/gopher, add the
# account, then change or delete the seeded one.
#
# SHIORI_HTTP_SECRET_KEY is deliberately unset: losing sessions on restart costs
# nothing, because the header re-authenticates every request.
{nice, ...}: {
  den.aspects.homelab.shiori.nixos = {config, ...}: {
    nice.web.services.shiori = {
      port = 8084;
      order = 80;
      # SAFETY: no +/- prefix means *set*, so a client's own Remote-User is
      # replaced, not appended.
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
      # The default covers RFC1918 only, not the loopback address caddy uses.
      SHIORI_SSO_PROXY_AUTH_TRUSTED = "127.0.0.1/32";
    };
  };
}
