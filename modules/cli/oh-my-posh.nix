{
  den.aspects.oh-my-posh.homeManager = {config, ...}: let
    # Nix strings have no \uXXXX escapes.
    icon = char: builtins.fromJSON ''"${char}"'';
  in {
    programs.oh-my-posh = {
      enable = true;
      settings = {
        "$schema" = "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json";
        version = 4;
        final_space = true;
        palettes = {
          template = ''{{ if eq .Env.NICE_APPEARANCE "light" }}light{{ else }}dark{{ end }}'';
          list = config.nice.theme.pair (variant: {inherit (variant.palette) pink lavender mauve;});
        };
        blocks = [
          {
            type = "prompt";
            alignment = "left";
            segments = [
              {
                type = "text";
                style = "plain";
                foreground = "p:mauve";
                template = "{{ with .Env.ZMX_SESSION }}{{ . }} {{ end }}";
              }
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
