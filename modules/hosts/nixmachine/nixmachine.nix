{den, ...}: {
  den.aspects.nixmachine = {
    includes = with den.aspects; [
      nixos-server
      audio # local playback
      # fwupd, so the Framework Desktop's BIOS can be updated from LVFS rather
      # than an EFI-shell USB stick.
      firmware
      nixmachine._
    ];

    nixos = {
      lib,
      pkgs,
      ...
    }: {
      # Required by ZFS: a stable 8-hex-digit host id (guards against importing a
      # pool last touched by a different machine). Generated once; keep it.
      networking.hostId = "1d847e7e";

      time.timeZone = "America/Chicago";

      # Boot — systemd-boot on the primary ESP (/boot). The disko layout also
      # mounts a second ESP at /boot/.fallback on the other NVMe; it's a spare
      # you sync by hand (systemd-boot doesn't mirror ESPs natively).
      # Deliberately NOT pinning linuxPackages_latest: ZFS lags the newest
      # kernel, so we ride NixOS's default (ZFS-compatible) kernel.
      boot.loader.systemd-boot.enable = true;

      boot.supportedFilesystems = ["zfs"];
      boot.zfs.forceImportRoot = false;

      services.zfs.autoScrub.enable = true; # monthly scrub
      services.zfs.trim.enable = true; # periodic TRIM for the NVMe-backed pools

      # No swap partition in the disko layout — use zram instead.
      zramSwap.enable = true;

      # Wired DHCP; headless box, so no NetworkManager.
      networking.useDHCP = lib.mkDefault true;

      # nftables firewall backend — modern choice (replaces iptables).
      networking.nftables.enable = true;

      # Audio — local playback out of an attached device (HDMI / analog / USB
      # DAC). PipeWire itself comes from modules/system/audio.nix.
      # rtkit lets PipeWire acquire realtime scheduling priority (avoids xruns).
      security.rtkit.enable = true;

      # GPU / graphics stack — DRI, Mesa/VAAPI, plus 32-bit userspace for apps
      # that need it. Enables accelerated HDMI output and video decode.
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      environment.systemPackages = with pkgs; [
        helix
        btop
        tmux
        alsa-utils # aplay -l / speaker-test to enumerate and test outputs
      ];
    };

    provides.to-users = {
      includes = [den.aspects.gaming]; # local play

      # Its users are in the `audio` group because this box is driven over
      # SSH, which has no seat session to hand out /dev/snd ACLs the way a
      # local login would.
      user.extraGroups = ["audio"];
    };
  };
}
