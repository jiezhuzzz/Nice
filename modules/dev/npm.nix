# npm via home-manager's programs.npm (installs nodejs + writes ~/.config/npm/npmrc).
# XDG-aligned layout: cache under ~/.cache/npm, and a ~/.local install prefix so
# `npm i -g` lands binaries in ~/.local/bin, lib in ~/.local/lib, man in
# ~/.local/share/man — instead of npm's default ~/.npm or the read-only nix nodejs
# prefix. ~/.local/bin is added to PATH in modules/bundles/core.nix (it's
# a generic user-bin dir, not npm-specific). Both paths are absolute Nix
# values, so no reliance on npm's own ${VAR} expansion.
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
