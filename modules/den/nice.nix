{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  fixed = type: default:
    mkOption {
      inherit type default;
      readOnly = true;
    };
in {
  options.nice = {
    user = {
      name = fixed types.str "jie";
      fullName = fixed types.str "jiezhuzzz";
      email = fixed types.str "jiezzz@duck.com";
      signingKey = fixed types.str "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqAEvgo0iyCrzXC2i03sTHQIAgSbzwPp9U44fIOGXMu";
    };

    facts = {
      domain = fixed types.str "jiezhu.me";
      forge = {
        host = fixed types.str "git.${config.nice.facts.domain}";
        sshPort = fixed types.port 2222;
      };
      podman = {
        subnet = fixed types.str "10.88.0.0/16";
        gateway = fixed types.str "10.88.0.1";
      };
    };
  };

  config._module.args.nice = config.nice;
}
