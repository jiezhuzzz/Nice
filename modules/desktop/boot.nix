{
  den.aspects.desktop.boot.nixos = {pkgs, ...}: {
    boot.loader.timeout = 0; # Hold Space during boot for menu

    # Esc drops from the splash to the plain-text LUKS prompt.
    boot.plymouth.enable = true;

    boot.kernelPackages = pkgs.linuxPackages_latest;
  };
}
