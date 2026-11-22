{den, ...}: {
  den.aspects.nixps = {
    includes = with den.aspects; [nixos-workstation laptop nixps._];

    nixos = {pkgs, ...}: {
      time.timeZone = "America/Chicago";

      environment.systemPackages = with pkgs; [
        wifitui
      ];

      swapDevices = [
        {
          device = "/swapfile";
          size = 8192;
        }
      ];
    };

    provides.to-users.homeManager = {lib, ...}: {
      programs.zed-editor.userSettings = {
        buffer_font_size = lib.mkForce 18;
        ui_font_size = 20;
      };
      programs.ghostty.settings.font-size = lib.mkForce 21;
    };
  };
}
