{
  den.aspects.herdr.homeManager = {
    programs.herdr = {
      enable = true;
      # herdr's own names: `catppuccin` is Mocha.
      settings.theme = {
        name = "catppuccin";
        auto_switch = true;
        light_name = "catppuccin-latte";
        dark_name = "catppuccin";
      };
    };
  };
}
