{
  den.aspects.eza.homeManager = {
    config,
    pkgs,
    ...
  }: {
    programs.eza = {
      enable = true;
      git = true;
    };

    nice.appearance.env.EZA_CONFIG_DIR = config.nice.theme.pair (variant: "${pkgs.linkFarm "eza-${variant.slug}" {"theme.yml" = "${config.catppuccin.sources.eza}/${variant.flavor}/${variant.accentSlug}.yml";}}");
  };
}
