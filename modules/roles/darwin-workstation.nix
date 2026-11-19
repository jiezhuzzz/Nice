{den, ...}: {
  den.aspects.darwin-workstation = {
    includes = [den.aspects.fonts];

    darwin = {pkgs, ...}: {
      nix.enable = false;

      environment.systemPackages = [pkgs.git];
    };

    provides.to-users.includes = with den.aspects; [
      macos
      workstation
      rclone
    ];
  };
}
