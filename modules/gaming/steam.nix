{
  den.aspects.gaming.steam = {
    user.extraGroups = ["games"];

    nixos = {pkgs, ...}: {
      programs.steam = {
        enable = true;

        extraCompatPackages = [pkgs.proton-ge-bin];

        # --hdr-enabled needs the gamescope-wsi layer inside Steam's FHS runtime.
        extraPackages = with pkgs; [
          mangohud
          gamescope-wsi
        ];

        gamescopeSession.enable = true;
        gamescopeSession.args = [
          "-w 3840"
          "-h 2160"
          "-r 120"
          "--xwayland-count 2"
          "-e"
          "--hdr-enabled"
          "--mangoapp"
          # Deliberately NO --cursor-scale-height: it linearly upscales the
          # client's cursor bitmap, so the result is blurry.
        ];
      };

      # Deliberately NO capSysNice: the wrapper's inheritable CAP_SYS_NICE leaks
      # into Steam's bubblewrap sandbox, which aborts with "bwrap: Unexpected
      # capabilities but not setuid".
      programs.gamescope.enable = true;

      programs.gamemode.enable = true;

      # Registering /fast/games as a Steam library is NOT declarable: it is Steam
      # client state in ~/.local/share/Steam/{config,steamapps}/libraryfolders.vdf,
      # added by hand. Edit both vdfs only with Steam stopped, since Steam
      # rewrites them on exit.
      users.groups.games = {};
    };
  };
}
