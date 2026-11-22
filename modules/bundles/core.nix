{den, ...}: {
  den.aspects.core = {
    includes = with den.aspects; [
      cli-packages
      aliases
      helix
      yazi
      atuin
      direnv
      git
      ssh
      eza
      fzf
      zellij
      herdr
      zoxide
      fd
      fastfetch
      bat
      bun
      gitui
      bottom
      ripgrep
      claude-code
      pi
      go
      uv
      npm
      cargo
      delta
      gh
    ];

    homeManager = {config, ...}: {
      home.preferXdgDirectories = true;
      xdg.enable = true;
      home.sessionPath = ["${config.home.homeDirectory}/.local/bin"];
      # SSH does not forward COLORTERM, and every terminal in use renders truecolor.
      home.sessionVariables.COLORTERM = "truecolor";
      programs.man.generateCaches = false;
      programs.home-manager.enable = true;
    };
  };
}
