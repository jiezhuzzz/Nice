{
  den.aspects.gh.homeManager = {
    config,
    pkgs,
    ...
  }: let
    inherit (config.catppuccin) sources;
    inherit (config.nice) theme;
  in {
    programs.gh = {
      enable = true;
      extensions = with pkgs; [
        gh-dash
        gh-poi
        gh-eco
        gh-s
        gh-f
      ];
    };

    nice.appearance.env = {
      GLAMOUR_STYLE = theme.pair (variant: "${sources.glamour}/${variant.slug}.json");
      # A config holding nothing but the theme: gh-dash fills in its defaults
      # for every key a config leaves out.
      GH_DASH_CONFIG = theme.pair (variant: "${sources.gh-dash}/${variant.flavor}/${variant.accentSlug}.yml");
    };
  };
}
