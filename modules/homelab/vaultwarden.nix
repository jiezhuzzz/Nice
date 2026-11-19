# No LAN port: Bitwarden's apps and browser extensions refuse a non-HTTPS
# server.
#
# The first account is created from /admin. ADMIN_TOKEN must be an Argon2 PHC
# hash (`vaultwarden hash`), not a plaintext password.
#
# TODO: the nightly backup overwrites a single copy and keeps no history; add
# ZFS snapshots.
{
  den.aspects.homelab.vaultwarden.nixos = {config, ...}: {
    nice.web.services.vault = {
      port = 8222;
      order = 60;
      tile = {
        title = "Vaultwarden";
        icon = "di:vaultwarden";
      };
    };

    services.vaultwarden = {
      enable = true;
      dbBackend = "sqlite"; # also required by backupDir (module assertion)
      backupDir = "/tank/cache/backups/vaultwarden";
      environmentFile = config.age.secrets.vaultwarden-admin-token.path;

      config = {
        DOMAIN = config.nice.web.services.vault.url;

        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = config.nice.web.services.vault.port;

        SIGNUPS_ALLOWED = false;
      };
    };
  };
}
