{
  den,
  lib,
  ...
}: {
  den.systems = ["x86_64-linux" "aarch64-darwin"];

  den.default = {
    nixos = {pkgs, ...}: {
      system.stateVersion = lib.mkDefault "26.05";

      nix.settings.experimental-features = ["nix-command" "flakes"];

      programs.nix-ld.enable = true;

      # lanzaboote (nixps) also reads this: its configurationLimit defaults to it.
      boot.loader.systemd-boot.configurationLimit = 5;
      boot.loader.efi.canTouchEfiVariables = true;

      environment.systemPackages = with pkgs; [
        git
        jq
        wget
      ];
    };

    darwin.system.stateVersion = lib.mkDefault 6;

    os.home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
    };

    homeManager.home = {
      stateVersion = lib.mkDefault "26.05";

      # noctalia's theme templates `sed -i` over ~/.config/ghostty/config, which
      # otherwise fails the whole switch with "would be clobbered". Activation
      # still fails if the .bak name is itself taken.
      backupFileExtension = "bak";
    };

    includes = [den.batteries."inputs'"];
  };

  den.schema.user.classes = lib.mkDefault ["homeManager"];

  den.schema.host.includes = [
    den.batteries.hostname
    den.batteries.mutual-provider
    ({host, ...}: {darwin.networking.computerName = host.hostName;})
  ];
}
