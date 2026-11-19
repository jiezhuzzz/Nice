# Caddy — HTTPS front door for the web UIs, reachable only over the tailnet
# (:443 is admitted via the trusted tailscale0 interface; see tailscale.nix —
# no LAN or WAN rule opens it). Serves *.jiezhu.me with a single wildcard
# Let's Encrypt cert via the ACME DNS-01 challenge against Cloudflare: no
# inbound port is ever opened to the internet, and one wildcard cert keeps
# the service names out of public Certificate Transparency logs. The public
# *.jiezhu.me A record points at nixmachine's tailnet IP (DNS-only / grey
# cloud in Cloudflare — the edge can't reach a 100.x address).
#
# The scoped API token (Zone → DNS → Edit, jiezhu.me only) is an agenix
# secret (secrets/caddy/cloudflare-token.age → CLOUDFLARE_API_TOKEN), fed in
# via the module's environmentFile and referenced in the tls directive.
{nice, ...}: {
  den.aspects.homelab.caddy.nixos = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.nice.web) ordered services;
    inherit (nice.facts) domain podman;

    # A service carrying `proxyDirectives` gets a reverse_proxy block instead of
    # the bare one-liner. Indentation is irrelevant — the module runs `caddy fmt`.
    proxyBlock = svc: let
      target = "127.0.0.1:${toString svc.port}";
    in
      if svc.proxyDirectives != null
      then ''
        reverse_proxy ${target} {
          ${svc.proxyDirectives}
        }''
      else "reverse_proxy ${target}";
  in {
    services.caddy = {
      enable = true;
      # Stock caddy can't do Cloudflare DNS-01; withPlugins rebuilds it with the
      # caddy-dns module baked in. To bump the plugin: set hash = lib.fakeHash,
      # rebuild, and copy the real hash from the mismatch error.
      package = pkgs.caddy.withPlugins {
        plugins = ["github.com/caddy-dns/cloudflare@v0.2.4"];
        hash = "sha256-QSiwKqKvSxhksWBF4/MlBOpyXba5xOQ2sRwA0R7399E=";
      };
      environmentFile = config.age.secrets.cloudflare-token.path;

      virtualHosts."*.${domain}".extraConfig =
        ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
            resolvers 1.1.1.1
          }

          # Forgejo CI job containers sit on podman's bridge, and :443 is open to
          # them there (modules/homelab/forgejo/runner.nix) because a job
          # clones from ROOT_URL. Only the git vhost is theirs to reach: several
          # of the blocks below *set* an SSO header, so a workflow that could
          # reach them would arrive already logged in as jie.
          @off-limits-to-ci {
            remote_ip ${podman.subnet}
            not host ${services.git.host}
          }
          handle @off-limits-to-ci {
            abort
          }

        ''
        + lib.concatMapStrings (svc: ''
          @${svc.name} host ${svc.host}
          handle @${svc.name} {
            ${proxyBlock svc}
          }

        '')
        ordered
        + ''
          # Unmatched subdomain: close the connection, don't serve a default page.
          handle {
            abort
          }
        '';
    };
  };
}
