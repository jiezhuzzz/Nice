{den, ...}: {
  den.aspects.nixos-workstation = {
    includes = with den.aspects; [
      audio
      firmware
      tailscale
    ];

    nixos.networking.networkmanager.enable = true;

    provides.to-users.includes = with den.aspects; [
      desktop
      workstation
      shpool
      zathura
    ];
  };
}
