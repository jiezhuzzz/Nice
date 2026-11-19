{den, ...}: {
  den.aspects.desktop.fontconfig = {
    includes = [den.aspects.fonts];

    # Without the SC pin, fontconfig may pick TC/JP/KR glyphs for ambiguous
    # Han characters.
    nixos.fonts.fontconfig.defaultFonts = {
      sansSerif = ["Noto Sans" "Source Han Sans SC"];
      serif = ["Noto Serif" "Source Han Serif SC"];
      monospace = ["JetBrainsMono Nerd Font" "Source Han Sans SC"];
      emoji = ["Noto Color Emoji"];
    };
  };
}
