{
  den.aspects.gaming.ten-foot-ui.nixos = {
    config,
    pkgs,
    ...
  }: {
    # gamescope's `--mangoapp` runs outside Steam's FHS, so mangohud must also be
    # on the system PATH.
    environment.systemPackages = [
      pkgs.mangohud
      config.nice.theme.cursor.package
    ];

    # 96 is the largest native bitmap the cursor theme ships, so it is drawn 1:1.
    # sessionVariables, not the session wrapper, so these also apply to a bare
    # `steam-gamescope` from a console login.
    environment.sessionVariables = {
      XCURSOR_THEME = config.nice.theme.cursor.name;
      XCURSOR_SIZE = "96";
    };

    environment.etc."MangoHud.conf".text = ''
      font_scale=5
    '';
  };
}
