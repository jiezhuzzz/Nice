# The module needs the runner UUID at eval time (it has no uuid_url). Forgejo
# and the runner derive it from the first 16 characters of the shared secret
# (gouuid.FromBytes over their ASCII bytes), so pinning that prefix fixes the
# UUID while the remaining 96 bits are minted on the box. `forgejo-cli actions
# register` drives Forgejo's internal HTTP API, so it must run after
# forgejo.service.
#
# SAFETY: job containers reach the forge through the podman bridge gateway,
# where :443 is open. caddy.nix must keep refusing every other vhost to the
# bridge subnet, or CI would arrive logged in as jie via the SSO headers.
#
# The cache proxy port is pinned because upstream picks a random one per start.
{nice, ...}: {
  den.aspects.homelab.forgejo.runner.nixos = {
    config,
    lib,
    ...
  }: let
    bridge = "podman0";
    inherit (nice.facts.podman) gateway;
    cacheProxyPort = 8100;

    domain = config.services.forgejo.settings.server.DOMAIN;
    # The unit services.forgejo-runner derives from the instance name.
    runnerUnit = "forgejo-runner-nixmachine.service";
    secretFile = "/var/lib/forgejo-runner-token/secret";

    secretPrefix = "1c933ccc66353a1a";
    uuid = let
      hex = lib.concatMapStrings (c: lib.toLower (lib.toHexString (lib.strings.charToInt c))) (lib.stringToCharacters secretPrefix);
      part = start: len: builtins.substring start len hex;
    in "${part 0 8}-${part 8 4}-${part 12 4}-${part 16 4}-${part 20 12}";
  in {
    services.forgejo-runner.instances.nixmachine = {
      enable = true;
      secrets.server.connections.default.token_url = secretFile;

      settings = {
        server.connections.default = {
          # No trailing slash: the runner appends its own paths to this.
          url = "https://${domain}";
          inherit uuid;
        };

        # A tag rather than a digest like the oci-containers pins elsewhere:
        # pinning would freeze CI's toolchain.
        runner.labels = [
          "ubuntu-latest:docker://node:24-bookworm"
          "docker:docker://node:24-bookworm"
        ];

        container = {
          # An empty `network` gives each job a fresh 10.89.x bridge, which the
          # firewall cannot name.
          network = "bridge";
          options = "--add-host=${domain}:${gateway}";
        };
        cache = {
          host = gateway;
          proxy_port = cacheProxyPort;
        };
      };
    };

    systemd.services.forgejo-runner-token = {
      description = "Mint, persist and register the Forgejo Actions runner secret";
      after = ["forgejo.service"];
      requires = ["forgejo.service"];
      before = [runnerUnit];
      requiredBy = [runnerUnit];
      path = [config.services.forgejo.package];

      environment = {
        FORGEJO_WORK_DIR = config.services.forgejo.stateDir;
        FORGEJO_CUSTOM = config.services.forgejo.customDir;
      };

      # `set -e` does not trip on a command substitution that fails inside an
      # argument list, so writing the random half inline would persist a bare
      # prefix that the file test then never retries.
      script = ''
        if [ ! -s '${secretFile}' ]; then
          random=$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')
          [ "''${#random}" -eq 24 ]
          printf '%s%s' '${secretPrefix}' "$random" > '${secretFile}'
        fi
        forgejo forgejo-cli actions register --secret-file '${secretFile}' --name nixmachine
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = config.services.forgejo.user;
        Group = config.services.forgejo.group;
        StateDirectory = "forgejo-runner-token";
        StateDirectoryMode = "0700";
        UMask = "0077";
      };
    };

    networking.firewall.interfaces.${bridge}.allowedTCPPorts = [443 cacheProxyPort];
  };
}
