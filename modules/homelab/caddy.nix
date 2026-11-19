# The *.jiezhu.me A record must stay DNS-only (grey cloud) in Cloudflare: the
# edge can't reach nixmachine's 100.x tailnet address.
{nice, ...}: {
  den.aspects.homelab.caddy.nixos = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.nice.web) ordered services;
    inherit (nice.facts) domain podman;

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

          # SAFETY: CI job containers on podman's bridge can reach :443
          # (forgejo/runner.nix). Several blocks below set an SSO header, so a
          # workflow reaching them would arrive logged in as jie.
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
          handle {
            abort
          }
        '';
    };
  };
}
