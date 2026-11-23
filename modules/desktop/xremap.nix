{inputs, ...}: let
  dualRole = held: alone: {
    inherit held alone;
    hold_threshold_millis = 0;
    alone_timeout_millis = 100;
  };
in {
  flake-file.inputs.xremap-flake = {
    url = "github:xremap/nix-flake";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-parts.follows = "flake-parts";
  };

  den.aspects.desktop.xremap = {
    nixos.hardware.uinput.enable = true;
    user.extraGroups = ["input" "uinput"];

    homeManager = {
      imports = [inputs.xremap-flake.homeManagerModules.default];

      # The first matching xremap rule wins, so the Helium rule must precede
      # the global modifier swap.
      services.xremap = {
        enable = true;
        withNiri = true;
        watch = true;
        config.modmap = [
          {
            name = "Helium Command key";
            # Helium ships no StartupWMClass, so its app_id is the binary name.
            application.only = ["/(?i)helium/"];
            remap = {
              Alt_L = "Control_L";
              Alt_R = "Control_R";
            };
          }
          {
            name = "macOS-style modifiers";
            remap = {
              Alt_L = "Super_L";
              Alt_R = "Super_R";
              Super_L = "Alt_L";
              Super_R = "Alt_R";
            };
          }
          {
            name = "Dual-role keys";
            remap = {
              CapsLock = dualRole "Control_L" "Esc";
              Shift_L = dualRole "Shift_L" ["Control_L" "Space"];
              Shift_R = dualRole "Shift_R" ["Control_L" "Space"];
            };
          }
        ];
      };

      # The application filter needs niri's IPC socket.
      systemd.user.services.xremap.Unit.After = ["niri.service"];
    };
  };
}
