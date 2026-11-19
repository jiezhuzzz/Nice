# Declarative Homebrew for nix-darwin.
#
# Two layers:
#   - nix-homebrew (zhaofengli/nix-homebrew) installs Homebrew itself and
#     pins taps to flake inputs (no mutable taps, no network at activation).
#   - nix-darwin's `homebrew` module manages which casks are installed.
{inputs, ...}: {
  flake-file.inputs = {
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  den.aspects.macos.homebrew.darwin = {config, ...}: {
    imports = [
      inputs.nix-homebrew.darwinModules.nix-homebrew
    ];

    nix-homebrew = {
      enable = true;
      enableRosetta = false; # Apple Silicon only, no Intel layer
      user = config.system.primaryUser;
      autoMigrate = false; # refuse if a non-nix brew install is already present
      mutableTaps = false; # taps come from flake inputs, not `brew tap`
      taps = {
        "homebrew/homebrew-core" = inputs.homebrew-core;
        "homebrew/homebrew-cask" = inputs.homebrew-cask;
      };
    };

    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false; # don't hit network on every darwin-rebuild
        upgrade = true;
        cleanup = "zap"; # remove anything not declared here
      };
      taps = builtins.attrNames config.nix-homebrew.taps;
      casks = [
        "1password"
        "balenaetcher"
        "betterdisplay"
        "figma"
        "fuse-t"
        "ghostty"
        "helium-browser"
        "iina"
        "karabiner-elements"
        "keka"
        "moonlight"
        "raycast"
        "skim"
        "squirrel-app"
        "stats"
        "tailscale-app"
        "zoom"
      ];
      masApps = {
        Amphetamine = 937984704;
        Bitwarden = 1352778147;
        "Pixelmator Pro" = 6746662575;
        Portal = 1436994560;
        WeChat = 836500024;
      };
    };
  };
}
