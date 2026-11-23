{
  den.aspects.ghostty.homeManager = {
    config,
    pkgs,
    lib,
    ...
  }: let
    inherit (config.nice.theme) variants;
  in {
    xdg.configFile = lib.concatMapAttrs (_: variant: {"ghostty/themes/${variant.slug}".source = "${config.catppuccin.sources.ghostty}/${variant.slug}.conf";}) variants;

    programs.ghostty = {
      enable = true;
      package =
        if pkgs.stdenv.hostPlatform.isDarwin
        then pkgs.ghostty-bin
        else pkgs.ghostty;
      settings =
        {
          theme = "light:${variants.light.slug},dark:${variants.dark.slug}";
          font-family = [
            "JetBrainsMonoNL Nerd Font"
            "Noto Sans Mono CJK SC"
          ];
          font-size = 16;
          window-padding-x = 8;
          window-padding-y = 8;
          cursor-style = "bar";
          # cursor-style-blink = false;
          adjust-cursor-thickness = "200%";
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
          command = lib.getExe config.programs.zellij.package;
          # `detect` keys off the command basename, so launching zellij would
          # skip injection into the fish panes it spawns.
          shell-integration = "fish";
          shell-integration-features = "cursor,sudo,ssh-env,ssh-terminfo,no-title,no-path";
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
