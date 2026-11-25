{den, ...}: {
  den.aspects.nixmachine = {
    includes = with den.aspects; [
      nixos-server
      audio
      firmware
      nixmachine._
    ];

    nixos = {
      lib,
      pkgs,
      ...
    }: {
      # ZFS refuses to import a pool last touched by a different host id, so
      # this must never change.
      networking.hostId = "1d847e7e";

      # /boot/.fallback is a spare ESP synced by hand: systemd-boot doesn't
      # mirror ESPs. Deliberately NOT pinning linuxPackages_latest: ZFS lags the
      # newest kernel.
      boot.loader.systemd-boot.enable = true;

      boot.supportedFilesystems = ["zfs"];
      boot.zfs.forceImportRoot = false;

      services.zfs.autoScrub.enable = true;
      services.zfs.trim.enable = true;

      zramSwap.enable = true;

      networking.useDHCP = lib.mkDefault true;

      networking.nftables.enable = true;

      security.rtkit.enable = true;

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      environment.systemPackages = with pkgs; [
        helix
        btop
        alsa-utils
      ];
    };

    provides.to-users = {
      includes = with den.aspects; [
        gaming
        hermes
      ];

      # Driven over SSH, which has no seat session to hand out /dev/snd ACLs.
      user.extraGroups = ["audio"];
    };
  };
}
