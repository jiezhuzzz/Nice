# services.memos.openFirewall is broken upstream (it reads a nonexistent
# cfg.port), so setting it fails evaluation.
#
# SAFETY: disallowUserRegistration lives in the database, not the environment.
# The first account to register becomes the instance owner, so register right
# after the first deploy, then turn registration off in Settings → Workspace.
#
# TODO: back up the sqlite database; the module ships no backup unit.
{
  den.aspects.homelab.memos.nixos = {config, ...}: {
    nice.web.services.memos = {
      port = 5230;
      order = 70;
      tile = {
        title = "Memos";
        icon = "di:memos";
      };
    };

    services.memos = {
      enable = true;

      # Defining `settings` discards the module's default attrset wholesale.
      # Its MEMOS_MODE is dropped deliberately: 0.29 has no --mode flag left.
      settings = {
        MEMOS_ADDR = "127.0.0.1";
        MEMOS_PORT = toString config.nice.web.services.memos.port;
        MEMOS_DRIVER = "sqlite";
        MEMOS_DATA = config.services.memos.dataDir;

        MEMOS_INSTANCE_URL = config.nice.web.services.memos.url;
      };
    };
  };
}
