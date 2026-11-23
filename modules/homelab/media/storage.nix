{nice, ...}: {
  den.aspects.homelab.media.storage.nixos = {lib, ...}: {
    # Must match the mountpoint of the tank/media dataset in
    # modules/hosts/nixmachine/disko.nix.
    options.nice.media.root = nice.fixed lib.types.str "/tank/media";

    config.users.groups.media = {};
  };
}
