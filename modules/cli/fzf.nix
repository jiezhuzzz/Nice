{
  den.aspects.fzf.homeManager = {config, ...}: {
    programs.fzf = {
      enable = true;

      # Atuin owns Ctrl-R; its shell integration is sourced after fzf's.
      historyWidget.bash.command = "";
      historyWidget.fish.command = "";
    };

    nice.appearance.env.FZF_DEFAULT_OPTS_FILE = config.nice.theme.pair (variant: "${config.catppuccin.sources.fzf}/catppuccin-fzf-${variant.flavor}.rc");
  };
}
