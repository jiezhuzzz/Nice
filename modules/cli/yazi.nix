{
  den.aspects.yazi.homeManager = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.catppuccin) sources;
    inherit (config.nice) theme;
  in {
    programs.yazi = {
      enable = true;
      theme.flavor = theme.pair (variant: variant.slug);
      # catppuccin/yazi ships whole theme files, which is what a flavor's
      # flavor.toml is; the tmTheme for file previews is the bat port's.
      flavors =
        lib.concatMapAttrs (_: variant: {
          ${variant.slug} = pkgs.linkFarm "${variant.slug}.yazi" {
            "flavor.toml" = "${sources.yazi}/${variant.flavor}/${variant.accentSlug}.toml";
            "tmtheme.xml" = "${sources.bat}/${variant.title}.tmTheme";
          };
        })
        theme.variants;
    };
  };
}
