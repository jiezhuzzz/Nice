{
  # TODO: return to nixpkgs' Helix once it carries a release with the
  # light/dark `theme` pair.
  flake-file.inputs.helix = {
    url = "github:helix-editor/helix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.helix.homeManager = {
    config,
    inputs',
    lib,
    ...
  }: let
    inherit (config.nice) theme;
  in {
    programs.helix = {
      enable = true;
      package = inputs'.helix.packages.default;
      defaultEditor = true;
      settings = {
        theme = theme.pair (variant: variant.slug);
        editor = {
          color-modes = true;
          soft-wrap.enable = true;
        };
      };
    };

    xdg.configFile = lib.concatMapAttrs (_: variant: {"helix/themes/${variant.slug}.toml".source = "${config.catppuccin.sources.helix}/no_italics/catppuccin_${variant.flavor}.toml";}) theme.variants;
  };
}
