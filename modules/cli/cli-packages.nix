{
  den.aspects.cli-packages.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      ast-grep
      comma
      lazyrsync
      nil
      rsync
      tea
      yubikey-manager
    ];
  };
}
