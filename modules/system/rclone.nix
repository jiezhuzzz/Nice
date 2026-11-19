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
      systemSecrets = osConfig.age.secrets or {};
      tokenPath = name: let
        secret = "rclone-${name}-token";
      in
        if builtins.hasAttr secret systemSecrets
        then systemSecrets.${secret}.path
        else "${config.xdg.dataHome}/rclone/${name}-token";
      gdriveTokenPath = tokenPath "gdrive";
      boxTokenPath = tokenPath "box";
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
    in {
      programs.rclone = {
        enable = true;
        remotes.gdrive = {
          config = {
            type = "drive";
            scope = "drive";
          };
          secrets.token = gdriveTokenPath;
          mounts."" = {
            enable = true;
            autoMount = true;
            mountPoint = "${config.home.homeDirectory}/GDrive";
            options = mountOptions;
          };
        };
        remotes.box = {
          config = {
            type = "box";
          };
          secrets.token = boxTokenPath;
          mounts."" = {
            enable = true;
            autoMount = true;
            mountPoint = "${config.home.homeDirectory}/Box";
            options = mountOptions;
          };
        };
      };
    };
  };
}
