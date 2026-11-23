{den, ...}: {
  den.aspects.nixps = {
    includes = with den.aspects; [nixos-workstation laptop nixps._];

    nixos = {pkgs, ...}: {
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

    provides.to-users.homeManager.programs.zed-editor.userSettings = {
      buffer_font_size = 18;
      ui_font_size = 20;
    };
  };
}
