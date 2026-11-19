{
  den.aspects.oh-my-posh.homeManager = {config, ...}: let
    # Nix doesn't support \uXXXX escapes; use fromJSON to get Unicode glyphs
    icon = char: builtins.fromJSON ''"${char}"'';
  in {
    programs.oh-my-posh = {
      enable = true;
      settings = {
        "$schema" = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json";
        version = 4;
        final_space = true;
        palette = {
          inherit (config.nice.theme.palette) pink lavender;
        };
        blocks = [
          {
            type = "prompt";
            alignment = "left";
            segments = [
              {
                type = "path";
                style = "plain";
                foreground = "p:pink";
                template = "{{ .Path }} ";
                properties = {
                  style = "letter";
                  home_icon = "~";
                };
              }
              {
                type = "git";
                style = "plain";
                foreground = "p:lavender";
                template = "{{ .HEAD }}{{ if or (.Working.Changed) (.Staging.Changed) }}*{{ end }} ";
                properties = {
                  branch_icon = "${icon "\\ue725"} ";
                  commit_icon = "${icon "\\uf417"} ";
                  fetch_status = true;
                };
              }
              {
                type = "text";
                style = "plain";
                foreground = "p:lavender";
                template = icon "\\uf105";
              }
            ];
          }
        ];
      };
    };
  };
}
