{den, ...}: {
  den.aspects.standalone = {
    includes = [den.aspects.server];

    homeManager.catppuccin.bottom.enable = false;
  };
}
