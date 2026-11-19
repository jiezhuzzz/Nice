# npm's default global prefix is the read-only nodejs store path.
{
  den.aspects.npm.homeManager = {config, ...}: {
    programs.npm = {
      enable = true;
      settings = {
        prefix = "${config.home.homeDirectory}/.local";
        cache = "${config.xdg.cacheHome}/npm";
      };
    };
  };
}
