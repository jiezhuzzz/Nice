{den, ...}: {
  den.aspects.fish = {
    includes = [(den.batteries.user-shell "fish")];

    homeManager = {
      config,
      lib,
      ...
    }: let
      inherit (config.nice) appearance theme;

      exports = vars: lib.concatLines (lib.mapAttrsToList (name: value: "set -gx ${name} ${lib.escapeShellArg value}") vars);
    in {
      # catppuccin/fish names a theme after its dark flavor; each one carries
      # Latte as its light section.
      xdg.configFile."fish/themes/catppuccin.theme".source = "${config.catppuccin.sources.fish}/${theme.variants.dark.slug}.theme";

      programs.fish.interactiveShellInit = ''
        fish_config theme choose catppuccin

        function __nice_appearance --on-variable fish_terminal_color_theme
            switch $fish_terminal_color_theme
                case light
                    ${exports appearance.exports.light}
                case '*'
                    ${exports appearance.exports.dark}
            end
        end
        __nice_appearance
      '';
    };
  };
}
