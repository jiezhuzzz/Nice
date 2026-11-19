{nice, ...}: {
  den.aspects.gaming.session.nixos = {pkgs, ...}: let
    # greetd starts sessions with a minimal PATH that lacks the NixOS system
    # profile. gamescope must resolve to the plain binary, not a
    # capSysNice-wrapped one (see steam.nix).
    # graphical-session.target has RefuseManualStart=yes; starting sunshine,
    # which Wants= it, pulls it in. No `exec`, so the EXIT trap can fire.
    gamescope-session = pkgs.writeShellScript "gamescope-session" ''
      export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"
      ${pkgs.systemd}/bin/systemctl --user import-environment PATH
      ${pkgs.systemd}/bin/systemctl --user start sunshine.service
      trap '${pkgs.systemd}/bin/systemctl --user stop sunshine.service' EXIT
      steam-gamescope &> /tmp/gamescope-session.log
    '';

    # Steam's Big Picture "Switch to Desktop" hangs in the gamescope session, so
    # this is the intended exit.
    game-stop = pkgs.writeShellScriptBin "game-stop" ''
      export PATH="/run/wrappers/bin:/run/current-system/sw/bin:$PATH"

      steam -shutdown &> /dev/null || true
      for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
        ${pkgs.procps}/bin/pgrep -x gamescope-wl > /dev/null || break
        ${pkgs.coreutils}/bin/sleep 1
      done

      ${pkgs.procps}/bin/pkill -TERM -f 'gamescope --steam'
      ${pkgs.coreutils}/bin/sleep 3

      # A SIGKILLed gamescope cannot reap its own children: the orphaned
      # gamescopereaper keeps the game running headless unless killed too.
      ${pkgs.procps}/bin/pkill -KILL -f 'gamescope --steam'
      ${pkgs.procps}/bin/pkill -KILL -x gamescopereaper
      exit 0
    '';
  in {
    environment.systemPackages = [
      game-stop
    ];

    # Setting initial_session flips services.greetd.restart to false by default,
    # so the autologin fires exactly once.
    services.greetd = {
      enable = true;
      settings = {
        initial_session = {
          command = "${gamescope-session}";
          user = nice.user.name;
        };
        default_session = {
          # A concrete shell, NOT `$SHELL`, which resolves to the `greeter`
          # user's nologin.
          command = "${pkgs.greetd}/bin/agreety --cmd ${pkgs.bashInteractive}/bin/bash";
        };
      };
    };
  };
}
