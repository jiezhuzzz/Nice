{
  den.aspects.claude-code.theme.homeManager = {
    config,
    lib,
    ...
  }: let
    inherit (config.nice) theme;
    inherit (config.programs.claude-code) configDir;

    channels = hex: map (offset: lib.fromHexString (builtins.substring offset 2 hex)) [1 3 5];
    mix = weight: over: under: "rgb(${lib.concatMapStringsSep "," toString (lib.zipListsWith (o: u: builtins.floor (o * weight + u * (1 - weight) + 0.5)) (channels over) (channels under))})";
    shimmer = color: mix 0.6 color "#ffffff";

    shimmering = lib.concatMapAttrs (key: color: {
      ${key} = color;
      "${key}Shimmer" = shimmer color;
    });

    # Claude Code (2.1.327) drops an override whose key the base theme lacks,
    # without a warning, so a key it renames falls back to the base color.
    overrides = p: let
      tint = weight: color: mix weight color p.base;
    in
      shimmering {
        claude = p.peach;
        permission = p.lavender;
        autoAccept = p.mauve;
        warning = p.yellow;
        fastMode = p.peach;
        inactive = p.overlay2;
        promptBorder = p.overlay1;
      }
      // lib.concatMapAttrs (name: color: {
        "rainbow_${name}" = color;
        "rainbow_${name}_shimmer" = shimmer color;
      }) {
        inherit (p) red yellow green blue;
        orange = p.peach;
        indigo = p.lavender;
        violet = p.mauve;
      }
      // lib.mapAttrs' (name: lib.nameValuePair "${name}_FOR_SUBAGENTS_ONLY") {
        inherit (p) red blue green yellow pink;
        purple = p.mauve;
        orange = p.peach;
        cyan = p.sky;
      }
      // {
        inherit (p) text;
        inverseText = p.base;
        subtle = p.surface2;
        background = p.sky;

        claudeBlue_FOR_SYSTEM_SPINNER = p.blue;
        claudeBlueShimmer_FOR_SYSTEM_SPINNER = shimmer p.blue;
        suggestion = p.lavender;
        remember = p.lavender;
        skill = p.mauve;
        merged = p.mauve;
        effortUltra = p.mauve;
        planMode = p.teal;
        ide = p.blue;
        bashBorder = p.pink;
        success = p.green;
        error = p.red;
        professionalBlue = p.sapphire;
        chromeYellow = p.yellow;
        briefLabelYou = p.blue;
        briefLabelClaude = p.peach;
        clawd_body = p.peach;
        clawd_background = p.crust;

        diffAdded = tint 0.25 p.green;
        diffRemoved = tint 0.25 p.red;
        diffAddedDimmed = tint 0.12 p.green;
        diffRemovedDimmed = tint 0.12 p.red;
        diffAddedWord = tint 0.5 p.green;
        diffRemovedWord = tint 0.5 p.red;

        userMessageBackground = p.surface0;
        userMessageBackgroundHover = p.surface1;
        bashMessageBackgroundColor = p.surface0;
        memoryBackgroundColor = p.surface0;
        composerSidebarBackground = p.mantle;
        selectionBg = p.surface2;
        rate_limit_fill = p.lavender;
        rate_limit_empty = p.surface1;
      };
  in {
    home.file =
      lib.concatMapAttrs (_: variant: {
        "${configDir}/themes/${variant.slug}.json".text = builtins.toJSON {
          name = variant.title;
          base = variant.appearance;
          overrides = overrides variant.palette;
        };
      })
      theme.variants;
  };
}
