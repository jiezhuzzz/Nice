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
      enableRosetta = false;
      user = config.system.primaryUser;
      autoMigrate = false;
      mutableTaps = false;
      taps = {
        "homebrew/homebrew-core" = inputs.homebrew-core;
        "homebrew/homebrew-cask" = inputs.homebrew-cask;
      };
    };

    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false;
        upgrade = true;
        cleanup = "zap";
      };
      taps = builtins.attrNames config.nix-homebrew.taps;
      casks = [
        "balenaetcher"
        "betterdisplay"
        "figma"
        "helium-browser"
        "iina"
        "karabiner-elements"
        "keka"
        "moonlight"
        "raycast"
        "skim"
        "squirrel-app"
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
