{
  den.aspects.fonts.os = {pkgs, ...}: {
    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.inconsolata
      maple-mono.NF

      noto-fonts

      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      lxgw-wenkai
      source-han-sans
      source-han-serif

      noto-fonts-color-emoji
    ];
  };
}
