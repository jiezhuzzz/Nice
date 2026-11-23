{
  den.aspects.delta.homeManager = {config, ...}: {
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
    };

    programs.git.includes = [{path = "${config.catppuccin.sources.delta}/catppuccin.gitconfig";}];

    nice.appearance.env.DELTA_FEATURES = config.nice.theme.pair (variant: variant.slug);
  };
}
