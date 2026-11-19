{
  den.aspects.fastfetch.homeManager = {pkgs, ...}: {
    programs.fastfetch = {
      enable = true;
      # The zpool module dlopens libzfs at runtime; the nixpkgs wrapper only
      # puts it on LD_LIBRARY_PATH with zfsSupport enabled.
      package = pkgs.fastfetch.override {
        zfsSupport = pkgs.stdenv.hostPlatform.isLinux;
      };
      settings = {
        # On ZFS, per-mountpoint disk stats cover only a single dataset.
        modules = [
          "title"
          "separator"
          "os"
          "host"
          "kernel"
          "uptime"
          "packages"
          "shell"
          "display"
          "de"
          "wm"
          "wmtheme"
          "theme"
          "icons"
          "font"
          "cursor"
          "terminal"
          "terminalfont"
          "cpu"
          "gpu"
          "memory"
          "swap"
          "disk"
          "zpool"
          "localip"
          "battery"
          "poweradapter"
          "locale"
          "break"
          "colors"
        ];
      };
    };
  };
}
