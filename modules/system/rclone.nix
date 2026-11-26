{nice, ...}: {
  den.aspects.rclone = {
    nixos = {
      # Mounts fail with EPERM without the setuid fusermount in /run/wrappers/bin.
      programs.fuse.enable = true;

      age.secrets.rclone-gdrive-token.owner = nice.user.name;
    };

    homeManager = {
      config,
      osConfig,
      ...
    }: let
      mount = directory: {
        enable = true;
        autoMount = true;
        mountPoint = "${config.home.homeDirectory}/${directory}";
        options = {
          vfs-cache-mode = "writes";
          vfs-cache-max-size = "10G";
          dir-cache-time = "1h";
          umask = "022";
        };
      };
    in {
      programs.rclone = {
        enable = true;
        remotes.gdrive = {
          config = {
            type = "drive";
            scope = "drive";
          };
          secrets.token = osConfig.age.secrets.rclone-gdrive-token.path;
          mounts."" = mount "GDrive";
        };
      };
    };
  };
}
