{
  den.aspects.fzf.homeManager = {
    programs.fzf = {
      enable = true;

      # Atuin owns Ctrl-R; its shell integration is sourced after fzf's.
      historyWidget.bash.command = "";
      historyWidget.fish.command = "";
    };
  };
}
