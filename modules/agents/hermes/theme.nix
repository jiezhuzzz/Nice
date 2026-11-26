{
  den.aspects.hermes.theme.homeManager = {
    config,
    pkgs,
    ...
  }: let
    inherit (config.nice) theme;

    colors = variant: let
      p = variant.palette;
      accent = p.${variant.accent};
    in {
      banner_border = accent;
      banner_title = accent;
      banner_accent = p.pink;
      banner_dim = p.overlay1;
      banner_text = p.text;
      ui_accent = accent;
      ui_label = p.lavender;
      ui_ok = p.green;
      ui_error = p.red;
      ui_warn = p.yellow;
      prompt = p.text;
      input_rule = p.overlay1;
      response_border = accent;
      shell_dollar = p.pink;
      session_label = p.lavender;
      session_border = p.overlay0;
      selection_bg = p.surface2;

      status_bar_bg = p.mantle;
      status_bar_text = p.subtext1;
      status_bar_strong = accent;
      status_bar_dim = p.overlay1;
      status_bar_good = p.green;
      status_bar_warn = p.yellow;
      status_bar_bad = p.peach;
      status_bar_critical = p.red;
      voice_status_bg = p.mantle;

      completion_menu_bg = p.mantle;
      completion_menu_current_bg = p.surface0;
      completion_menu_meta_bg = p.mantle;
      completion_menu_meta_current_bg = p.surface0;
    };
  in {
    services.hermes-agent = {
      # No `background` key: with one, Hermes paints the terminal and takes the
      # skin's polarity instead of probing the terminal for light or dark.
      hermesHomeFiles."skins/catppuccin.yaml" = (pkgs.formats.yaml {}).generate "catppuccin.yaml" {
        name = "catppuccin";
        description = "Catppuccin, following the terminal between light and dark";
        colors = colors theme.variants.dark;
        light_colors = colors theme.variants.light;
      };
      settings.display = {
        skin = "catppuccin";
        # The classic CLI (v0.23.4) ignores `light_colors`; only the TUI
        # switches palettes with the terminal.
        interface = "tui";
      };
    };
  };
}
