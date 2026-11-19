{
  den.aspects.desktop.pointer-cursor.homeManager = {config, ...}: {
    home.pointerCursor = {
      enable = true;
      inherit (config.nice.theme.cursor) name package size;
      gtk.enable = true;
    };
  };
}
