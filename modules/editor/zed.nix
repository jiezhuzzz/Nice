{
  den.aspects.zed.homeManager = {pkgs, ...}: {
    programs.zed-editor = {
      enable = true;
      extensions = ["nix" "latex"];
      extraPackages = with pkgs; [
        nil
        alejandra
        texlab
        tex-fmt
        ruff
        ty
      ];
      userSettings = {
        buffer_font_family = "JetBrainsMonoNL Nerd Font";
        buffer_font_size = 14;
        on_last_window_closed = "quit_app";
        helix_mode = true;
        colorize_brackets = true;
        soft_wrap = "editor_width";
        relative_line_numbers = "enabled";
        inlay_hints.enabled = true;
        sticky_scroll.enabled = true;
        file_scan_exclusions = ["**/.direnv" "**/.ruff_cache" "**/__pycache__" "**/.pytest_cache" "**/.mypy_cache" "**/.venv" "**/node_modules" "..."];
        lsp.nil.initialization_options.nix.flake.autoArchive = true;
        languages = {
          Nix = {
            language_servers = ["nil"];
            formatter = {
              external = {
                command = "alejandra";
                arguments = ["-q" "-"];
              };
            };
            format_on_save = "on";
          };
          LaTeX = {
            language_servers = ["texlab"];
            tab_size = 2;
            formatter = {
              external = {
                command = "tex-fmt";
                arguments = ["--stdin" "--nowrap" "--format-tables"];
              };
            };
            format_on_save = "on";
          };
          Python = {
            language_servers = ["ruff" "ty"];
            formatter = "language_server";
            format_on_save = "on";
          };
        };
      };
    };
  };
}
