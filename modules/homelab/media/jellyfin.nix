{
  den.aspects.homelab.media.jellyfin.nixos = {
    nice.web.services.jellyfin = {
      port = 8096;
      lan = true;
      order = 20;
      tile = {
        title = "Jellyfin";
        icon = "di:jellyfin";
      };
    };

    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };
    users.users.jellyfin.extraGroups = ["media" "render" "video"];
  };
}
