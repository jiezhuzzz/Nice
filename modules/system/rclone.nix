# macOS mounts need a FUSE provider (fuse-t cask).
{
  den.aspects.rclone = {
    # nixpkgs' fuse looks for its setuid mount helper in /run/wrappers/bin
    # (-DFUSERMOUNT_DIR); without it libfuse falls back to the non-setuid copy in
    # rclone's closure and every mount fails with EPERM.
    nixos.programs.fuse.enable = true;

    homeManager = {
      config,
      osConfig ? {},
      pkgs,
      ...
    }: let
      # Standalone home-manager servers have no system agenix and take a
      # hand-placed token under the XDG data dir.
      tokenPath = name: osConfig.age.secrets."rclone-${name}-token".path or "${config.xdg.dataHome}/rclone/${name}-token";
      # macOS emits AppleDouble `._*` shadow files when writing xattrs to a
      # filesystem without xattr support, such as fuse-t.
      rcloneFilter = pkgs.writeText "rclone-mount-filter" ''
        - ._*
        - .DS_Store
      '';
      mountOptions = {
        vfs-cache-mode = "writes";
        vfs-cache-max-size = "10G";
        dir-cache-time = "1h";
        umask = "022";
        filter-from = "${rcloneFilter}";
      };
      mount = directory: {
        enable = true;
        autoMount = true;
        mountPoint = "${config.home.homeDirectory}/${directory}";
        options = mountOptions;
      };
    in {
      programs.rclone = {
        enable = true;
        remotes.gdrive = {
          config = {
            type = "drive";
            scope = "drive";
          };
          secrets.token = tokenPath "gdrive";
          mounts."" = mount "GDrive";
        };
        remotes.box = {
          config.type = "box";
          secrets.token = tokenPath "box";
          mounts."" = mount "Box";
        };
      };
    };
  };
}
