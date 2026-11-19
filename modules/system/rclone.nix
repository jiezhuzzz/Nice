# rclone remotes + auto-mounts. Cross-platform: home-manager emits systemd
# user services on Linux and launchd agents on macOS.
# macOS additionally needs a FUSE provider for mounts (fuse-t cask).
#
# Where a token lives depends on whether this host's *system* layer decrypts
# it, which is not the same question as which platform it is: the macOS hosts
# and nixmachine both get it from agenix, while chameleon and the other
# standalone home-manager servers have no system agenix at all and take a
# hand-placed file under the XDG data dir. Keying off the secret's own
# declaration keeps those two cases apart and makes the path track whatever
# agenix actually chose.
{
  den.aspects.rclone = {
    # NixOS support for these mounts: the setuid fusermount3 they mount through.
    #
    # programs.fuse.enable is what puts a setuid fusermount3 in /run/wrappers/bin,
    # which is where nixpkgs' fuse is compiled to look for its mount helper
    # (-DFUSERMOUNT_DIR, set in pkgs/os-specific/linux/fuse/common.nix). Without it
    # libfuse falls back to the plain copy in rclone's own closure, which carries
    # no setuid bit, so mount(2) returns EPERM and every mount unit dies with
    # "fusermount3: mount failed: Operation not permitted". The macOS hosts mount
    # through fuse-t, and the standalone-home-manager servers run on distros that
    # ship their own setuid helper, which leaves nixmachine as the only NixOS host
    # that mounts anything. userAllowOther stays off — these mounts are
    # single-user and pass no allow_other.
    nixos.programs.fuse.enable = true;

    homeManager = {
      config,
      osConfig ? {},
      pkgs,
      ...
    }: let
      systemSecrets = osConfig.age.secrets or {};
      tokenPath = name: let
        secret = "rclone-${name}-token";
      in
        if builtins.hasAttr secret systemSecrets
        then systemSecrets.${secret}.path
        else "${config.xdg.dataHome}/rclone/${name}-token";
      gdriveTokenPath = tokenPath "gdrive";
      boxTokenPath = tokenPath "box";
      # Drop macOS metadata cruft (AppleDouble shadow files emitted whenever a
      # file with xattrs is written to a non-xattr-supporting FS like fuse-t/NFS,
      # plus Finder's .DS_Store). Bidirectional in mount mode: cruft never
      # reaches the cloud and never appears in the local mount view.
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
