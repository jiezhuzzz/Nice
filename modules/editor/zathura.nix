{
  den.aspects.zathura.homeManager = {
    config,
    pkgs,
    ...
  }: let
    inherit (config.nice) theme;
    colors = "${config.xdg.stateHome}/zathura/colors";
    source = variant: "${config.catppuccin.sources.zathura}/${variant.slug}";
    busctl = "${pkgs.systemd}/bin/busctl --user";
    reload = pkgs.writeShellScript "zathura-reload" ''
      ${busctl} --no-legend list | while read -r name _; do
        if [[ $name == org.pwmt.zathura.PID-* ]]; then
          ${busctl} call "$name" /org/pwmt/zathura org.pwmt.zathura SourceConfig
        fi
      done
    '';
  in {
    # Linux-only on purpose: on the Macs zed-latex auto-detects Skim instead.
    programs.zathura = {
      enable = true;
      # zathura cannot tell light from dark: its colors are whatever the config
      # sets. noctalia keeps `colors` on the current mode's file, and the dark
      # one is what a start before its first write gets.
      extraConfig = ''
        include ${source theme.variants.dark}
        include ${colors}
      '';
    };

    programs.noctalia.settings.theme.templates.user.zathura = {
      input_path_modes = theme.pair source;
      output_path = colors;
      post_hook = "${reload}";
    };
  };
}
