{den, ...}: {
  den.aspects.nixmini = {
    includes = [den.aspects.darwin-workstation];

    provides.to-users.homeManager = {
      programs.ghostty.settings.custom-shader = [
        "${./shaders/inside-the-matrix.glsl}"
        "${./shaders/cursor_blaze.glsl}"
      ];
    };
  };
}
