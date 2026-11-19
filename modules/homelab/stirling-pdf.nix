# Stirling PDF — self-hosted PDF toolkit (merge/split/OCR/convert/sign, etc.).
# Native NixOS service (DynamicUser); the module bundles the full PDF toolchain
# (libreoffice, ocrmypdf, tesseract, ghostscript, qpdf, ...). Configured via env
# vars. Stateless tool; advanced-ops/Calibre left off to keep the closure lean.
#
# v2 ships with security.enableLogin=true by default (login/account subsystem is
# compiled in), so we disable it via SECURITY_ENABLELOGIN — single-user tool
# behind the firewall/tailnet, no auth needed.
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

    # Upstream has no openFirewall option (the port is an opaque env var, so the
    # module can't know it); allowedTCPPorts is exactly what openFirewall would do.
    networking.firewall.allowedTCPPorts = [config.nice.web.services.pdf.port];
  };
}
