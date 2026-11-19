{
  den.aspects.fonts.os = {pkgs, ...}: {
    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.inconsolata
      maple-mono.NF

      noto-fonts

      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      lxgw-wenkai # handwriting-style Chinese (kept for reading/decorative)
      source-han-sans # PingFang-alike (思源黑体)
      source-han-serif # serif companion (思源宋体)

      # afdko#1216 (the aarch64 test crash that blocked this) is fixed upstream;
      # nixpkgs afdko 5.0.1 handles arch-specific tests. Re-pin/disable only if a
      # darwin-rebuild build starts failing in the afdko dependency again.
      noto-fonts-color-emoji
    ];
  };
}
