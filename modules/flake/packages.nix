{lib, ...}: let
  directory = ../../pkgs;
in {
  flake.overlays.default = final: _prev:
    lib.packagesFromDirectoryRecursive {
      inherit (final) callPackage;
      inherit directory;
    };

  perSystem = {pkgs, ...}: let
    packages = lib.filterAttrs (_: lib.meta.availableOn pkgs.stdenv.hostPlatform) (lib.mapAttrs (name: _: pkgs.${name}) (builtins.readDir directory));
  in {
    inherit packages;
    checks = packages;
    apps.sync-rclone-tokens = {
      program = pkgs.sync-rclone-tokens;
      inherit (pkgs.sync-rclone-tokens) meta;
    };
  };
}
