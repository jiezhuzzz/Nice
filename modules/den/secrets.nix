{
  den,
  inputs,
  lib,
  nice,
  ...
}: let
  inherit (lib) mkOption types;

  scope = types.enum ["personal" "homelab"];

  # Editing and recovery key, held in the password manager.
  password-manager = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIkFCNadE6kTViKssYg8SBEHf9H0BEa92p3l0UfMELOF";

  hosts = lib.attrValues (lib.mergeAttrsList (lib.attrValues den.hosts));
  secrets = lib.attrValues nice.secrets;
  recipients = file: map (host: host.hostKey) (lib.filter (host: lib.any (secret: secret.file == file && lib.elem secret.scope host.secrets) secrets) hosts) ++ [password-manager];
in {
  options.nice.secrets = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        file = mkOption {type = types.str;};
        scope = mkOption {type = scope;};
      };
    });
  };

  config = {
    flake-file.inputs.agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    den.schema.host = {
      options = {
        hostKey = mkOption {type = types.str;};
        secrets = mkOption {
          type = types.listOf scope;
          default = [];
        };
      };
      includes = [
        ({host, ...}: {
          nixos.imports = [inputs.agenix.nixosModules.default];
          darwin.imports = [inputs.agenix.darwinModules.default];
          os.age = {
            identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
            secrets = lib.mapAttrs (_: secret:
              {file = ../../secrets + "/${secret.file}";}
              // lib.optionalAttrs (secret.scope == "personal") {owner = nice.user.name;})
            (lib.filterAttrs (_: secret: lib.elem secret.scope host.secrets) nice.secrets);
          };
        })
      ];
    };

    flake.lib.agenixRules = lib.listToAttrs (map (secret: {
        name = secret.file;
        value.publicKeys = recipients secret.file;
      })
      secrets);
  };
}
