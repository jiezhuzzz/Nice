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
