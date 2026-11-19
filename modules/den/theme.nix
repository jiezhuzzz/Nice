{
  inputs,
  lib,
  ...
}: let
  inherit (lib) mkOption types;

  options = {pkgs, ...}: {
    options.nice.theme = {
      flavor = mkOption {
        type = types.enum ["latte" "frappe" "macchiato" "mocha"];
        default = "mocha";
      };
      cursor = {
        name = mkOption {
          type = types.str;
          default = "Banana";
        };
        package = mkOption {
          type = types.package;
          default = pkgs.banana-cursor;
        };
        size = mkOption {
          type = types.ints.positive;
          default = 40;
        };
      };
    };
  };

  catppuccin = {config, ...}: {
    options.nice.theme.palette = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      default = lib.mapAttrs (_: color: color.hex) (lib.importJSON "${config.catppuccin.sources.palette}/palette.json").${config.catppuccin.flavor}.colors;
    };

    config.catppuccin = {
      enable = true;
      autoEnable = true;
      flavor = config.nice.theme.flavor;
    };
  };
in {
  flake-file.inputs.catppuccin = {
    url = "github:catppuccin/nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.default = {
    nixos.imports = [inputs.catppuccin.nixosModules.catppuccin options catppuccin];
    homeManager.imports = [inputs.catppuccin.homeModules.catppuccin options catppuccin];
  };
}
