# SAFETY: SSH binds 0.0.0.0:2222 with no allowedTCPPorts entry, so only the
# trusted tailscale0 interface reaches it.
#
# Registration is off, so create the first account once after the first deploy
# (`-H` because forgejo aborts if HOME is unset):
#
#   sudo -u forgejo -H forgejo -c /var/lib/forgejo/custom/conf/app.ini \
#     admin user create --username jie --email jiezhu@uchicago.edu \
#     --admin --random-password
{nice, ...}: {
  den.aspects.homelab.forgejo.forge.nixos = {config, ...}: {
    nice.web.services.git = {
      port = 8081;
      order = 120;
      tile = {
        title = "Forgejo";
        icon = "di:forgejo";
      };
    };

    services.forgejo = {
      enable = true;
      lfs.enable = true;

      dump = {
        enable = true;
        backupDir = "/tank/cache/backups/forgejo";
        type = "tar.zst";
        # Two weeks, not the module's four: every archive is a full copy of
        # every repository.
        age = "2w";
      };

      settings = {
        server = {
          HTTP_ADDR = "127.0.0.1";
          HTTP_PORT = config.nice.web.services.git.port;

          # runner.nix reads DOMAIN back out to keep the two in step.
          DOMAIN = config.nice.web.services.git.host;
          ROOT_URL = "${config.nice.web.services.git.url}/";

          START_SSH_SERVER = true;
          SSH_LISTEN_HOST = "0.0.0.0";
          SSH_LISTEN_PORT = nice.facts.forge.sshPort;
          SSH_PORT = nice.facts.forge.sshPort;
          SSH_DOMAIN = config.nice.web.services.git.host;
          BUILTIN_SSH_SERVER_USER = "git";
          SSH_CREATE_AUTHORIZED_KEYS_FILE = false;
        };

        service.DISABLE_REGISTRATION = true;
        session.COOKIE_SECURE = true;

        actions.ENABLED = true;
      };
    };

    # catppuccin.autoEnable in modules/den/theme.nix would otherwise theme the
    # forge.
    catppuccin.forgejo.enable = false;

    # The admin CLI must match the service build: `forgejo admin` and `forgejo
    # doctor` write to the live database, and version skew applies migrations
    # twice.
    environment.systemPackages = [config.services.forgejo.package];
  };
}
