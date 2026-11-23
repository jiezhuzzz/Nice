{
  inputs,
  lib,
  nice,
  ...
}: let
  inherit (lib) mkOption types;
  inherit (nice) fixed;

  palettes = lib.importJSON "${inputs.catppuccin-palette}/palette.json";

  variants =
    lib.mapAttrs (appearance: flavor: rec {
      inherit appearance flavor;
      accent = "mauve";
      slug = "catppuccin-${flavor}";
      accentSlug = "${slug}-${accent}";
      title = "Catppuccin ${lib.toSentenceCase flavor}";
      palette = lib.mapAttrs (_: color: color.hex) palettes.${flavor}.colors;
    }) {
      light = "latte";
      dark = "mocha";
    };

  theme = {pkgs, ...}: {
    # catppuccin/nix builds the palette as a package, and reading a package
    # while evaluating needs a builder for the host's platform.
    config.catppuccin.sources.palette = inputs.catppuccin-palette.outPath;

    options.nice.theme = {
      variants = fixed types.raw variants;
      pair = fixed types.raw (f: lib.mapAttrs (_: f) variants);
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
in {
  flake-file.inputs = {
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin-palette = {
      url = "github:catppuccin/palette";
      flake = false;
    };
  };

  den.default = {
    nixos = {
      imports = [inputs.catppuccin.nixosModules.catppuccin theme];
      # What NixOS itself themes (boot splash, console) is drawn before any
      # appearance is known, so it stays on the dark variant.
      catppuccin = {
        enable = true;
        autoEnable = true;
        inherit (variants.dark) flavor accent;
      };
    };
    homeManager = {
      imports = [inputs.catppuccin.homeModules.catppuccin theme];
      # Here only for `catppuccin.sources`, each port's theme files: a tool
      # picks its own pair from them, since catppuccin/nix applies one flavor.
      catppuccin = {
        enable = true;
        autoEnable = false;
      };
    };
  };
}
