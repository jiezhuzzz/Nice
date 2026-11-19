{
  den.aspects.desktop.pointer-cursor.homeManager = {config, ...}: {
    home.pointerCursor = {
      # Explicit since home-manager deprecated inferring this from the
      # presence of the other options.
      enable = true;
      inherit (config.nice.theme.cursor) name package size;
      gtk.enable = true;
    };
  };
}
