# Shared storage + permissions for the media stack. Every service runs as its
# own user but must share files so completed downloads can be hardlinked from
# Transmission's download dir into the library. A shared `media` group + setgid
# 2775 dirs + a group-writable umask (set per-service) makes that work.
{
  den.aspects.homelab.media.storage.nixos = {lib, ...}: {
    # Must match the mountpoint of the tank/media dataset in
    # modules/hosts/nixmachine/disko.nix.
    options.nice.media.root = lib.mkOption {
      type = lib.types.str;
      default = "/tank/media";
      readOnly = true;
    };

    config.users.groups.media = {};
  };
}
