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
        # CSS shorthand: [vertical horizontal].
        margin = [8 8];
        cursor.shape = "block";
        copy-on-select = true;
        window =
          {
            opacity-cells = true;
          }
          // (
            if pkgs.stdenv.hostPlatform.isDarwin
            then {
              opacity = 0.8;
              blur = "macos-glass-clear";
            }
            else {
              opacity = 0.5;
              blur = false;
            }
          );
        # Make alt+backspace send the classic "meta-DEL" byte pair — ESC
        # (\x1b) then DEL (\x7f) — which readline, fish, zsh and pi's editor
        # all read as delete-word-backward. Recommended by pi's terminal-setup
        # docs (libexec/pi/docs/terminal-setup.md); Rio's own default for this
        # chord drops out once a program turns on the Kitty keyboard protocol.
        #
        # Nix has no \x escape, so the two bytes come in through JSON.
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
