{
  inputs,
  self,
  ...
}: let
  settings = {
    config.allowUnfree = true;
    overlays = [self.overlays.default];
  };
in {
  flake-file.inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  perSystem = {system, ...}: {
    _module.args.pkgs = import inputs.nixpkgs (settings // {inherit system;});
  };

  den.default.os.nixpkgs = settings;
}
