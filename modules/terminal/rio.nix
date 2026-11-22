{
  den.aspects.rio.homeManager = {
    pkgs,
    lib,
    ...
  }: {
    programs.rio = {
      enable = true;
      settings = {
        fonts = {
          size = 16;
          family = "JetBrainsMono Nerd Font";
          # Rio takes a single family, not Ghostty's ordered fallback list, so
          # the CJK face has to be pinned per codepoint range instead.
          symbol-map = [
            {
              start = "2E80";
              end = "9FFF";
              font-family = "Noto Sans Mono CJK SC";
            }
            {
              start = "FF00";
              end = "FFEF";
              font-family = "Noto Sans Mono CJK SC";
            }
          ];
        };
        margin = [8 8];
        cursor.shape = "block";
        copy-on-select = true;
        navigation.mode = "Plain";
        window =
          {
            opacity-cells = true;
          }
          // (
            if pkgs.stdenv.hostPlatform.isDarwin
            then {
              opacity = 0.8;
              blur = "macos-glass-clear";
              decorations = "Buttonless";
            }
            else {
              opacity = 0.5;
              blur = false;
            }
          );
        # Rio's own alt+backspace default drops out once a program turns on the
        # Kitty keyboard protocol (libexec/pi/docs/terminal-setup.md).
        bindings.keys =
          [
            {
              key = "backspace";
              "with" = "alt";
              esc = builtins.fromJSON "\"\\u001b\\u007f\"";
            }
          ]
          ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            {
              key = "c";
              "with" = "super";
              action = "copy";
            }
            {
              key = "v";
              "with" = "super";
              action = "paste";
            }
            {
              key = "t";
              "with" = "super";
              action = "createtab";
            }
            {
              key = "w";
              "with" = "super";
              action = "closesplitortab";
            }
            {
              key = "n";
              "with" = "super";
              action = "createwindow";
            }
            {
              key = "q";
              "with" = "super";
              action = "quit";
            }
          ];
      };
    };
  };
}
