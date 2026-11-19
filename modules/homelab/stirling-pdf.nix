{
  den.aspects.homelab.stirling-pdf.nixos = {config, ...}: {
    nice.web.services.pdf = {
      port = 8082;
      lan = true;
      order = 40;
      tile = {
        title = "Stirling PDF";
        icon = "di:stirling-pdf";
      };
    };

    services.stirling-pdf = {
      enable = true;
      environment = {
        SERVER_PORT = config.nice.web.services.pdf.port;
        SECURITY_ENABLELOGIN = "false";
      };
    };

    # Upstream has no openFirewall option.
    networking.firewall.allowedTCPPorts = [config.nice.web.services.pdf.port];
  };
}
