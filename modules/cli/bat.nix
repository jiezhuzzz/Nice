{
  den.aspects.bat.homeManager = {config, ...}: {
    programs.bat.enable = true;

    # Not bat's own `--theme-light`/`--theme-dark`: those ask the terminal, and
    # bat only asks when it writes to one, so piped output would lose its theme.
    nice.appearance.env.BAT_THEME = config.nice.theme.pair (variant: variant.title);
  };
}
