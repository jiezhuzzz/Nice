{
  den.aspects.desktop.linux-packages.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      wechat-uos
    ];
  };
}
