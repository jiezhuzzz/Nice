{
  den.aspects.bottom.homeManager = {
    config,
    pkgs,
    ...
  }: {
    programs.bottom = {
      enable = true;
      # bottom takes its colors from the config file alone, and only a flag
      # names another file.
      package = config.nice.appearance.wrap pkgs.bottom (config.nice.theme.pair (variant: ["--config_location" "${config.catppuccin.sources.bottom}/${variant.flavor}.toml"]));
    };
  };
}
