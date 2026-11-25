# SAFETY: the server authenticates nothing beyond the client ID, so the tailnet
# is the whole access control: never a LAN port or a non-loopback bind.
{nice, ...}: {
  den.aspects.homelab.taskchampion.nixos = {config, ...}: {
    nice.web.services.tasks = {
      port = 10222;
      order = 140;
    };

    assertions = [
      {
        assertion = config.nice.web.services.tasks.host == nice.facts.tasks.host;
        message = "nice.web.services.tasks serves ${config.nice.web.services.tasks.host}, but Taskwarrior clients sync to nice.facts.tasks.host (${nice.facts.tasks.host})";
      }
    ];

    services.taskchampion-sync-server = {
      enable = true;
      inherit (config.nice.web.services.tasks) port;
      allowClientIds = [nice.facts.tasks.clientId];
    };
  };
}
