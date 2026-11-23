{
  den.aspects.rime.homeManager = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit (config.nice.theme) variants;
    inherit (pkgs.stdenv.hostPlatform) isDarwin;

    # Squirrel writes colors as 0xBBGGRR.
    bgr = hex: "0x${lib.concatMapStrings (offset: builtins.substring offset 2 hex) [5 3 1]}";
    schemeName = variant: "catppuccin_${variant.flavor}";
    # The roles of catppuccin/squirrel, which catppuccin/nix does not package.
    scheme = variant:
      {name = variant.title;}
      // lib.mapAttrs (_: bgr) {
        back_color = variant.palette.crust;
        border_color = variant.palette.mantle;
        text_color = variant.palette.subtext1;
        label_color = variant.palette.subtext0;
        candidate_text_color = variant.palette.text;
        hilited_back_color = variant.palette.mauve;
        hilited_candidate_text_color = variant.palette.base;
        hilited_candidate_label_color = variant.palette.surface0;
        hilited_text_color = variant.palette.surface2;
        hilited_comment_text_color = variant.palette.surface0;
        comment_text_color = variant.palette.surface2;
      };
    rimeDir =
      if isDarwin
      then "Library/Rime"
      else ".local/share/fcitx5/rime";
  in {
    home.file."${rimeDir}/default.custom.yaml".text = builtins.toJSON {
      patch = {
        # nixpkgs renames rime-ice's default.yaml to avoid colliding with the
        # frontend's base data.
        __include = "rime_ice_suggestion:/";
        schema_list = [{schema = "double_pinyin_flypy";}];
        # Replaces the whole default switch_key map, not just the Shift keys.
        "ascii_composer/switch_key" = {
          Shift_L = "inline_ascii";
          Shift_R = "noop";
          Control_L = "noop";
          Control_R = "noop";
          Caps_Lock = "clear";
        };
      };
    };

    # rime-ice's secondary translators default to full-pinyin spelling rules.
    home.file."${rimeDir}/melt_eng.custom.yaml".text = builtins.toJSON {
      patch."speller/algebra".__include = "melt_eng.schema.yaml:/algebra_double_pinyin_flypy";
    };

    home.file."${rimeDir}/radical_pinyin.custom.yaml".text = builtins.toJSON {
      patch."speller/algebra".__include = "radical_pinyin.schema.yaml:/algebra_double_pinyin_flypy";
    };

    home.file."${rimeDir}" = {
      source = "${pkgs.rime-ice}/share/rime-data";
      recursive = true;
    };

    home.file."Library/Rime/squirrel.custom.yaml" = {
      enable = isDarwin;
      text = builtins.toJSON {
        patch =
          {
            "style/candidate_list_layout" = "linear";
            "style/inline_preedit" = true;
            "style/color_scheme" = schemeName variants.light;
            "style/color_scheme_dark" = schemeName variants.dark;
          }
          // lib.concatMapAttrs (_: variant: {"preset_color_schemes/${schemeName variant}" = scheme variant;}) variants;
      };
    };

    # Rime's deployer only recompiles when a source file is newer than the
    # compiled output in build/, and Nix store files have a fixed 1970 mtime,
    # so build/ goes stale. A running fcitx5 keeps serving Rime without build/
    # until it restarts.
    home.activation.rimeRedeploy = lib.hm.dag.entryAfter ["writeBoundary"] (
      ''
        run rm -rf $VERBOSE_ARG "$HOME/${rimeDir}/build"
      ''
      + (
        if isDarwin
        then ''
          squirrel="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
          if [ -x "$squirrel" ]; then
            run "$squirrel" --reload || true
          fi
        ''
        else ''
          run ${pkgs.systemd}/bin/systemctl --user try-restart 'app-org.fcitx.Fcitx5@autostart.service' || true
        ''
      )
    );
  };
}
