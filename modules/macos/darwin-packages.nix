{
  den.aspects.macos.darwin-packages.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      macmon
      poppler-utils
    ];
  };
}
