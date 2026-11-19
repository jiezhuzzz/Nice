# RSSHub — generates feeds for sites that publish none; subscribe from
# miniflux.nix at http://127.0.0.1:1200/<route>, browse routes at
# https://rsshub.jiezhu.me. No firewall port: it has no auth and every route
# fetches an arbitrary upstream, so a LAN port would be a free fetch proxy.
{
  den.aspects.homelab.rsshub.nixos = {config, ...}: {
    nice.web.services.rsshub = {
      port = 1200;
      order = 100;
      # dashboard-icons has no SVG for this one, and glance defaults to .svg.
      tile = {
        title = "RSSHub";
        icon = "di:rsshub.png";
      };
    };

    services.rsshub = {
      enable = true;
      settings.PORT = config.nice.web.services.rsshub.port;
    };
  };
}
