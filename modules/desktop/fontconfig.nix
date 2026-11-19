{den, ...}: {
  den.aspects.desktop.fontconfig = {
    includes = [den.aspects.fonts];

    # Latin first, Simplified-Chinese as explicit fallback. Without the SC
    # pin, fontconfig may pick TC/JP/KR glyphs for ambiguous Han characters
    # (wrong strokes for a Chinese reader).
    # Chinese default: Source Han Sans SC — the canonical open substitute
    # for Apple's PingFang SC (same modern, neutral sans-serif style).
    nixos.fonts.fontconfig.defaultFonts = {
      sansSerif = ["Noto Sans" "Source Han Sans SC"];
      serif = ["Noto Serif" "Source Han Serif SC"];
      monospace = ["JetBrainsMono Nerd Font" "Source Han Sans SC"];
      emoji = ["Noto Color Emoji"];
    };
  };
}
