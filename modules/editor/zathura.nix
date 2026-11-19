{
  den.aspects.zathura.homeManager = {
    # Linux-only on purpose: on the Macs zed-latex auto-detects Skim instead.
    #
    # Declared via programs.zathura rather than home.packages so the catppuccin
    # flake themes it.
    programs.zathura.enable = true;
  };
}
