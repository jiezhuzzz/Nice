# SAFETY: RPC has no password; rpc-whitelist is the only gate on :9091.
{
  den.aspects.homelab.media.transmission.nixos = {config, ...}: {
    nice.web.services.transmission = {
      port = 9091;
      lan = true;
      order = 30;
      tile = {
        title = "Transmission";
        icon = "di:transmission";
      };
    };

    services.transmission = {
      enable = true;
      group = "media";
      downloadDirPermissions = "2775";
      openFirewall = true;
      openRPCPort = true;
      settings = {
        umask = 2;
        download-dir = "${config.nice.media.root}/downloads";
        incomplete-dir = "${config.nice.media.root}/downloads/.incomplete";
        incomplete-dir-enabled = true;

        rpc-bind-address = "0.0.0.0";
        rpc-port = config.nice.web.services.transmission.port;
        rpc-authentication-required = false;
        rpc-whitelist-enabled = true;
        # Direct tailnet access (100.x source) is 403'd; remote use goes via caddy.
        rpc-whitelist = "127.0.0.1,192.168.86.*";
        rpc-host-whitelist-enabled = false; # avoid 403 when hitting the UI by IP
      };
    };
  };
}
