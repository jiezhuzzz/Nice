{inputs, ...}: {
  flake-file.inputs.xremap-flake = {
    url = "github:xremap/nix-flake";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-parts.follows = "flake-parts";
  };

  den.aspects.desktop.xremap = {
    # xremap runs as a Home Manager user service. It reads physical keyboards
    # through /dev/input and emits its virtual keyboard through /dev/uinput.
    nixos.hardware.uinput.enable = true;
    user.extraGroups = ["input" "uinput"];

    homeManager = {
      imports = [inputs.xremap-flake.homeManagerModules.default];

      # One user-level remapper owns all keyboard transformations. The first
      # matching xremap rule wins, so the browser-specific Alt rule must precede
      # the global macOS-style modifier swap.
      services.xremap = {
        enable = true;
        withNiri = true;
        watch = true;
        config.modmap = [
          {
            name = "Helium Command key";
            # Matched against the Wayland app_id. Helium ships no StartupWMClass,
            # so this is Chromium's default (the binary name); confirm with
            # `niri msg windows` if the remap stops applying after an update.
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
              CapsLock = {
                held = "Control_L";
                alone = "Esc";
                hold_threshold_millis = 0;
                alone_timeout_millis = 100;
              };
              Shift_L = {
                held = "Shift_L";
                alone = ["Control_L" "Space"];
                hold_threshold_millis = 0;
                alone_timeout_millis = 100;
              };
              Shift_R = {
                held = "Shift_R";
                alone = ["Control_L" "Space"];
                hold_threshold_millis = 0;
                alone_timeout_millis = 100;
              };
            };
          }
        ];
      };

      # Niri publishes NIRI_SOCKET before graphical-session.target becomes active;
      # the explicit dependency also documents the application-filter requirement.
      systemd.user.services.xremap.Unit.After = ["niri.service"];
    };
  };
}
