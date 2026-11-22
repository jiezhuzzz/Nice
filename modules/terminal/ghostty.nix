{
  den.aspects.ghostty.homeManager = {
    pkgs,
    lib,
    ...
  }: {
    programs.ghostty = {
      enable = true;
      package =
        if pkgs.stdenv.hostPlatform.isDarwin
        then pkgs.ghostty-bin
        else pkgs.ghostty;
      settings =
        {
          font-family = [
            "JetBrainsMono Nerd Font"
            "Noto Sans Mono CJK SC"
          ];
          font-size = 16;
          window-padding-x = 8;
          window-padding-y = 8;
          cursor-style = "block";
          copy-on-select = true;
          # pi otherwise doesn't see alt+backspace under Ghostty
          # (libexec/pi/docs/terminal-setup.md). Ghostty's `text:` action parses
          # a Zig string literal, so the \x escapes must reach the config verbatim.
          keybind =
            [
              ''alt+backspace=text:\x1b\x7f''
            ]
            ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              "super+c=copy_to_clipboard"
              "super+v=paste_from_clipboard"
              "super+t=new_tab"
              "super+w=close_surface"
              "super+n=new_window"
              "super+q=quit"
            ];
          shell-integration-features = "ssh-terminfo";
          background-opacity-cells = true;
        }
        // (
          if pkgs.stdenv.hostPlatform.isDarwin
          then {
            background-opacity = 0.8;
            background-blur = "macos-glass-clear";
            macos-titlebar-style = "hidden";
          }
          else {
            background-opacity = 0.5;
          }
        );
    };
  };
}
