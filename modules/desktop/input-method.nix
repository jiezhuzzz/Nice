{
  den.aspects.desktop.input-method.nixos = {pkgs, ...}: {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [
        (fcitx5-rime.override {rimeDataPkgs = [rime-ice];})
      ];
      fcitx5.settings.addons.classicui.globalSection = {
        "Vertical Candidate List" = false;
        WheelForPaging = true;
        Font = "Noto Sans CJK SC 16";
        MenuFont = "Noto Sans CJK SC 14";
        UseInputMethodLanguageToDisplayText = true;
        UseDarkTheme = false;
        UseAccentColor = false;
        PerScreenDPI = false;
        ForceWaylandDPI = 0;
        EnableFractionalScale = true;
      };
    };
  };
}
