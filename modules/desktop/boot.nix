{
  den.aspects.desktop.boot.nixos = {pkgs, ...}: {
    boot.loader.timeout = 0; # Hold Space during boot for menu

    boot.plymouth.enable = true;

    boot.kernelPackages = pkgs.linuxPackages_latest;
  };
}
