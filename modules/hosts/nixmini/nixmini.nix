{den, ...}: {
  den.aspects.nixmini = {
    includes = [den.aspects.darwin-workstation];

    provides.to-users.homeManager = {
      programs.ghostty.settings.custom-shader = [
        "${./shaders/inside-the-matrix.glsl}"
        "${./shaders/cursor_blaze.glsl}"
      ];

      # Rio has no custom-shader hook, so Ghostty's cursor_blaze becomes the
      # built-in trail; the matrix background has no counterpart.
      programs.rio.settings.effects = {
        trail-cursor = true;
        trail-cursor-opacity = 0.5;
      };
    };
  };
}
