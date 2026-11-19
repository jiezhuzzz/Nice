{
  den.aspects.rime.homeManager = {
    pkgs,
    lib,
    ...
  }: let
    inherit (pkgs.stdenv.hostPlatform) isDarwin;
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
      text = ''
        patch:
          style/candidate_list_layout: linear
          style/inline_preedit: true
      '';
    };

    # Rime's deployer only recompiles when a source file is newer than the
    # compiled output in build/, and Nix store files have a fixed 1970 mtime,
    # so build/ goes stale. A running fcitx5 keeps serving Rime without build/
    # until it restarts.
    home.activation.rimeRedeploy = lib.hm.dag.entryAfter ["writeBoundary"] (
      ''
        run rm -rf $VERBOSE_ARG "$HOME/${rimeDir}/build"
      ''
      + lib.optionalString (!isDarwin) ''
        run ${pkgs.systemd}/bin/systemctl --user try-restart 'app-org.fcitx.Fcitx5@autostart.service' || true
      ''
      + lib.optionalString isDarwin ''
        squirrel="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
        if [ -x "$squirrel" ]; then
          run "$squirrel" --reload || true
        fi
      ''
    );
  };
}
