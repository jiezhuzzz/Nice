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

      # Run-time linker shim so unpatched, dynamically-linked binaries (e.g.
      # tools fetched by language toolchains, VS Code / Cursor remote servers,
      # prebuilt release binaries) can find an ld.so and the usual libraries
      # under /run/current-system/sw/share/nix-ld/lib. Left at the default
      # library set; add programs.nix-ld.libraries here if a specific binary
      # needs more.
      programs.nix-ld.enable = true;

      # Read by systemd-boot (nixmachine) and by lanzaboote (nixps), whose own
      # configurationLimit defaults to this one.
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

      # Move a conflicting file to <name>.bak instead of aborting activation.
      # Without this, any app that rewrites a home-manager-managed config in
      # place fails the whole switch with "would be clobbered" — noctalia's
      # theme templates did exactly that to ~/.config/ghostty/config by running
      # `sed -i` over the store symlink.
      #
      # Note this trades a loud failure for a silent one: the file is replaced
      # and the old copy left as .bak, so a config being fought over is no
      # longer obvious from the switch output. Activation also still fails if
      # the .bak name is itself taken, so stale backups need clearing.
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
