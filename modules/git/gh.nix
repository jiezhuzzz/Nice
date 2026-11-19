{
  den.aspects.gh.homeManager = {pkgs, ...}: {
    programs.gh = {
      enable = true;
      extensions = with pkgs; [
        gh-dash
        gh-poi
        gh-eco
        gh-s
        gh-f
      ];
    };
  };
}
