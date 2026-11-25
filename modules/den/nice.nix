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
    fixed = fixed types.raw fixed;

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
      # Every replica shares one client ID: it names the task list, not a device.
      tasks = {
        host = fixed types.str "tasks.${config.nice.facts.domain}";
        clientId = fixed types.str "68eb0b54-dd59-4455-96d9-67495b9f84d5";
      };
      podman = {
        subnet = fixed types.str "10.88.0.0/16";
        gateway = fixed types.str "10.88.0.1";
      };
      # Chicago.
      location = {
        latitude = fixed types.float 41.8781;
        longitude = fixed types.float (-87.6298);
        timeZone = fixed types.str "America/Chicago";
      };
    };
  };

  config._module.args.nice = config.nice;
}
