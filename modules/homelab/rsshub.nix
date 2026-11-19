# SAFETY: no firewall port. RSSHub has no auth and every route fetches an
# arbitrary upstream, so a LAN port would be a free fetch proxy.
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
