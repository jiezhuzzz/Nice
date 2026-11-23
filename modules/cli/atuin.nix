{
  den.aspects.atuin.homeManager = {
    config,
    lib,
    ...
  }: let
    inherit (config.nice) theme;
  in {
    programs.atuin.enable = true;

    xdg.configFile = lib.concatMapAttrs (_: variant: {"atuin/themes/${variant.accentSlug}.toml".source = "${config.catppuccin.sources.atuin}/${variant.flavor}/${variant.accentSlug}.toml";}) theme.variants;

    nice.appearance.env.ATUIN_THEME__NAME = theme.pair (variant: variant.accentSlug);
  };
}
