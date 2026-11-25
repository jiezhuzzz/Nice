{nice, ...}: {
  den.aspects.homelab.taskchampion.nixos = {config, ...}: {
    nice.web.services.tasks = {
      port = 10222;
      order = 140;
    };

    services.taskchampion-sync-server = {
      enable = true;
      inherit (config.nice.web.services.tasks) port;
      allowClientIds = [nice.facts.tasks.clientId];
    };
  };
}
