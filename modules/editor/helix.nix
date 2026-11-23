{
  # TODO: return to nixpkgs' Helix once it carries a release with the
  # light/dark `theme` pair.
  flake-file.inputs.helix = {
    url = "github:helix-editor/helix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.helix.homeManager = {
    config,
    inputs',
    lib,
    ...
  }: let
    inherit (config.nice) theme;
  in {
    programs.helix = {
      enable = true;
      # HACK: helix pins tree-sitter-perl 1.0.0, whose vendored bsearch.c
      # collides with the C23 `bsearch` macro in glibc 2.44. Drop once helix
      # pins 1.1.1 or later, which deletes that file.
      package = inputs'.helix.packages.default.override {
        grammarOverlays = [
          (_: prev: {
            perl = prev.perl.overrideAttrs (old: {
              env = old.env // {NIX_CFLAGS_COMPILE = "-std=gnu17";};
            });
          })
        ];
      };
      defaultEditor = true;
      settings = {
        theme = theme.pair (variant: variant.slug);
        editor = {
          color-modes = true;
          soft-wrap.enable = true;
          rainbow-brackets = true;
          lsp.auto-document-highlight = true;
          buffer-picker.start-position = "previous";
          word-completion.trigger-length = 4;
          # Hides only the modal: a workspace's .helix config and git config
          # stay gated until `:workspace-trust`.
          workspace-trust.prompt = false;
        };
      };
    };

    xdg.configFile = lib.concatMapAttrs (_: variant: {"helix/themes/${variant.slug}.toml".source = "${config.catppuccin.sources.helix}/no_italics/catppuccin_${variant.flavor}.toml";}) theme.variants;
  };
}
