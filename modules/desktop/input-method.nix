{
  den.aspects.desktop.input-method.nixos = {
    config,
    pkgs,
    ...
  }: let
    inherit (config.nice.theme) variants;
  in {
    # Its one flavor would collide with the pair below.
    catppuccin.fcitx5.enable = false;

    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [
        (fcitx5-rime.override {rimeDataPkgs = [rime-ice];})
        config.catppuccin.sources.fcitx5
      ];
      fcitx5.settings.addons.classicui.globalSection = {
        "Vertical Candidate List" = false;
        WheelForPaging = true;
        Font = "Noto Sans CJK SC 16";
        MenuFont = "Noto Sans CJK SC 14";
        UseInputMethodLanguageToDisplayText = true;
        Theme = variants.light.accentSlug;
        DarkTheme = variants.dark.accentSlug;
        # Follows the desktop's color-scheme setting.
        UseDarkTheme = true;
        UseAccentColor = false;
        PerScreenDPI = false;
        ForceWaylandDPI = 0;
        EnableFractionalScale = true;
      };
    };
  };
}
