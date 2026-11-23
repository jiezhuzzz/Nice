# Ports held by services without a vhost, so not in nice.web.services: 8080
# metatube, 4000 litellm, 8100 the runner's cache, 8088+ ad-hoc dsh web apps.
{nice, ...}: {
  den.aspects.homelab.web.nixos = {
    config,
    lib,
    ...
  }: let
    inherit (lib) mkOption types;
    cfg = config.nice.web;
    inherit (nice.facts) domain;

    service = types.submodule ({
      name,
      config,
      ...
    }: {
      options = {
        port = mkOption {type = types.port;};
        lan = mkOption {
          type = types.bool;
          default = false;
        };
        order = mkOption {type = types.int;};
        host = nice.fixed types.str "${name}.${domain}";
        url = nice.fixed types.str "https://${config.host}";
        proxyDirectives = mkOption {
          type = types.nullOr types.lines;
          default = null;
        };
        tile = mkOption {
          type = types.nullOr (types.submodule {
            options = {
              title = mkOption {type = types.str;};
              icon = mkOption {type = types.str;};
            };
          });
          default = null;
        };
      };
    });
  in {
    options.nice.web = {
      services = mkOption {
        type = types.attrsOf service;
        default = {};
      };
      ordered = nice.fixed (types.listOf types.raw) (lib.sortOn (svc: svc.order) (lib.mapAttrsToList (name: svc: svc // {inherit name;}) cfg.services));
    };

    config.assertions =
      [
        {
          assertion = lib.allUnique (map (svc: svc.port) cfg.ordered);
          message = "nice.web.services: two services claim the same port";
        }
        {
          assertion = lib.allUnique (map (svc: svc.order) cfg.ordered);
          message = "nice.web.services: two services share an order";
        }
      ]
      ++ map (svc: {
        assertion = svc.lan == lib.elem svc.port config.networking.firewall.allowedTCPPorts;
        message = "nice.web.services.${svc.name}: lan = ${lib.boolToString svc.lan} disagrees with networking.firewall.allowedTCPPorts for port ${toString svc.port}";
      })
      cfg.ordered;
  };
}
